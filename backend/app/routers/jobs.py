from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile

from app import db
from app.config import Settings
from app.extraction import Profile, extract_profile_text
from app.jd import RequirementParser
from app.parsers import extract_text
from app.ranking import RankingService

router = APIRouter(tags=["jobs"])


def _settings() -> Settings:
    from app.config import settings

    return settings


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _require_job(job_id: str) -> dict:
    async with db.connect() as conn:
        row = await conn.execute("SELECT * FROM jobs WHERE id = ?", (str(job_id),))
        job = await row.fetchone()
    if job is None:
        raise HTTPException(status_code=404, detail="job_not_found")
    return db.row_to_job(job)


def _save_file(upload_dir: Path, suffix: str, content: bytes) -> str:
    upload_dir.mkdir(parents=True, exist_ok=True)
    path = upload_dir / f"{uuid4().hex}{suffix}"
    path.write_bytes(content)
    return str(path)


def _delete_storage_file(path: str | None) -> None:
    if not path:
        return
    try:
        Path(path).unlink(missing_ok=True)
    except OSError:
        pass


@router.post("/jobs", status_code=201)
async def create_job(
    title: str = Form(...),
    description: str = Form(""),
    jd_file: UploadFile | None = File(None),
) -> dict:
    """Create a vacancy from pasted text and/or an uploaded JD file (PDF/DOCX/TXT)."""
    title = title.strip()
    if not title:
        raise HTTPException(status_code=422, detail="job_title_required")

    settings = _settings()
    jd_bytes = await jd_file.read() if jd_file else None
    jd_key = None
    if jd_bytes:
        try:
            jd_text = await extract_text(jd_file.filename or "job.txt", jd_bytes)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        if not description.strip():
            description = jd_text
        suffix = Path(jd_file.filename or "job.txt").suffix.lower()
        jd_key = _save_file(settings.upload_dir / "jd", suffix, jd_bytes)

    # If description is valid JSON, normalize it into requirements.
    # Otherwise, parse it as plain text with structure_jd().
    # Always keep the original description text for display.
    parser = RequirementParser()
    requirements = parser.parse(description) if description.strip() else None

    job = {
        "id": str(uuid4()),
        "title": title,
        "description": description.strip(),
        "requirements": requirements,
        "status": "open",
        "created_at": _now(),
        "updated_at": _now(),
    }
    async with db.connect() as conn:
        await conn.execute(
            "INSERT INTO jobs (id, title, description, requirements, status, created_at, updated_at, jd_file)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                job["id"],
                job["title"],
                job["description"],
                _json_dumps(job["requirements"]),
                job["status"],
                job["created_at"],
                job["updated_at"],
                jd_key,
            ),
        )
        await conn.commit()
    return {"job": _job_payload(job, jd_key=jd_key)}


@router.get("/jobs")
async def list_jobs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    offset = (page - 1) * limit
    async with db.connect() as conn:
        rows = await (
            await conn.execute(
                "SELECT * FROM jobs ORDER BY created_at DESC LIMIT ? OFFSET ?",
                (limit + 1, offset),
            )
        ).fetchall()
        page_rows = rows[:limit]
        has_more = len(rows) > limit
        if page_rows:
            placeholders = ",".join("?" for _ in page_rows)
            count_rows = await (
                await conn.execute(
                    f"SELECT job_id, COUNT(*) AS c FROM cvs WHERE job_id IN ({placeholders}) GROUP BY job_id",
                    tuple(j["id"] for j in page_rows),
                )
            ).fetchall()
        else:
            count_rows = []
    counts = {r["job_id"]: r["c"] for r in count_rows}
    jobs = []
    for j in (db.row_to_job(r) for r in page_rows):
        payload = _job_payload(j)
        payload["cv_count"] = counts.get(j["id"], 0)
        jobs.append(payload)
    return {
        "count": len(jobs),
        "jobs": jobs,
        "meta": {"page": page, "limit": limit, "has_more": has_more},
    }


@router.get("/jobs/{job_id}")
async def get_job(job_id: str) -> dict:
    job = await _require_job(job_id)
    return {"job": _job_payload(job)}


@router.delete("/jobs/{job_id}")
async def delete_job(job_id: str) -> dict:
    """Delete a job and everything attached to it: CVs, uploaded files, and JD."""
    job = await _require_job(job_id)
    cvs = await _load_cvs(job_id)
    for cv in cvs:
        _delete_storage_file(cv.get("storage_path"))
    if job.get("jd_file"):
        _delete_storage_file(job["jd_file"])
    async with db.connect() as conn:
        await conn.execute("DELETE FROM cvs WHERE job_id = ?", (job["id"],))
        await conn.execute("DELETE FROM jobs WHERE id = ?", (job["id"],))
        await conn.commit()
    return {"job_id": job["id"], "deleted": True}


@router.delete("/jobs/{job_id}/cvs/{cv_id}")
async def delete_cv(job_id: str, cv_id: str) -> dict:
    """Delete a single candidate/CV from a job."""
    job = await _require_job(job_id)
    async with db.connect() as conn:
        row = await conn.execute(
            "SELECT * FROM cvs WHERE id = ? AND job_id = ?",
            (str(cv_id), job["id"]),
        )
        cv = await row.fetchone()
        if cv is None:
            raise HTTPException(status_code=404, detail="cv_not_found")
        _delete_storage_file(cv["storage_path"])
        await conn.execute(
            "DELETE FROM cvs WHERE id = ? AND job_id = ?",
            (str(cv_id), job["id"]),
        )
        await conn.commit()
    return {"job_id": job["id"], "cv_id": str(cv_id), "deleted": True}


@router.post("/jobs/{job_id}/cvs", status_code=201)
async def upload_cvs(
    job_id: str,
    files: list[UploadFile] = File(...),
) -> dict:
    """Upload one or many CV files (PDF/DOCX/TXT). Each is parsed immediately."""
    job = await _require_job(job_id)
    settings = _settings()
    results = []
    for file in files:
        name = file.filename or "unnamed"
        content = await file.read()
        try:
            text = await extract_text(name, content)
            profile, source = await extract_profile_text(settings, text, name)
            storage = _save_file(settings.upload_dir, Path(name).suffix.lower(), content)
            cv_id = str(uuid4())
            async with db.connect() as conn:
                await conn.execute(
                    "INSERT INTO cvs (id, job_id, file_name, storage_path, status,"
                    " candidate_name, profile_text, skills, years_experience, education,"
                    " certifications, source)"
                    " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        cv_id,
                        job["id"],
                        name,
                        storage,
                        "parsed",
                        profile.candidate_name,
                        text,
                        _json_dumps(profile.skills),
                        profile.years_experience,
                        profile.education,
                        _json_dumps(profile.certifications),
                        source,
                    ),
                )
                await conn.commit()
            results.append(
                {
                    "cv_id": cv_id,
                    "file_name": name,
                    "status": "parsed",
                    "candidate_name": profile.candidate_name,
                    "source": source,
                    "error": None,
                }
            )
        except ValueError as exc:
            results.append(
                {"cv_id": None, "file_name": name, "status": "failed", "candidate_name": None, "error": str(exc)}
            )
    return {"job_id": job["id"], "uploaded": len(results), "results": results}


@router.get("/jobs/{job_id}/cvs")
async def list_cvs(job_id: str) -> dict:
    job = await _require_job(job_id)
    cvs = await _load_cvs(job_id)
    return {"job_id": job["id"], "count": len(cvs), "results": [_cv_payload(cv) for cv in cvs]}


@router.post("/jobs/{job_id}/rank")
async def rank_job(job_id: str) -> dict:
    """Score + rank every parsed CV, with reasoning (LLM when configured, else rules)."""
    job = await _require_job(job_id)
    if not job.get("requirements"):
        raise HTTPException(status_code=422, detail="job_missing_description")

    cvs = await _load_cvs(job_id)
    parsed = [cv for cv in cvs if cv["status"] in ("parsed", "ranked")]
    if not parsed:
        return {"job_id": job["id"], "count": 0, "results": []}

    settings = _settings()
    profiles = [Profile.from_cv(cv) for cv in parsed]
    ranked, source = await RankingService(settings).rank(job["requirements"], profiles, parsed)

    async with db.connect() as conn:
        for i, item in enumerate(ranked):
            await conn.execute(
                "UPDATE cvs SET status = 'ranked', overall_score = ?, bucket = ?,"
                " recommendation = ?, explanation = ?, strengths = ?, weaknesses = ?,"
                " skill_gaps = ?, skill_score = ?, experience_score = ?,"
                " education_score = ?, certification_score = ?, ranked_at = ?"
                " WHERE id = ?",
                (
                    item["overall_score"],
                    item["bucket"],
                    item["recommendation"],
                    item["explanation"],
                    _json_dumps(item["strengths"]),
                    _json_dumps(item["weaknesses"]),
                    _json_dumps(item["skill_gaps"]),
                    item["skill_score"],
                    item["experience_score"],
                    item["education_score"],
                    item["certification_score"],
                    item["ranked_at"],
                    item["id"],
                ),
            )
        await conn.commit()

    for i, item in enumerate(ranked):
        item["rank"] = i + 1
    return {
        "job_id": job["id"],
        "source": source,
        "count": len(ranked),
        "results": [_cv_payload(item) for item in ranked],
    }


@router.get("/jobs/{job_id}/rankings")
async def get_rankings(job_id: str) -> dict:
    job = await _require_job(job_id)
    cvs = await _load_cvs(job_id)
    ranked = [cv for cv in cvs if cv["overall_score"] is not None]
    ranked.sort(key=lambda c: c["overall_score"], reverse=True)
    for i, item in enumerate(ranked):
        item["rank"] = i + 1
    return {"job_id": job["id"], "count": len(ranked), "results": [_cv_payload(item) for item in ranked]}


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

async def _load_cvs(job_id: str) -> list[dict]:
    async with db.connect() as conn:
        rows = await (await conn.execute("SELECT * FROM cvs WHERE job_id = ?", (job_id,))).fetchall()
    return [db.row_to_cv(r) for r in rows]


def _job_payload(job: dict, *, jd_key: str | None = None) -> dict:
    payload = {
        "job_id": job["id"],
        "title": job["title"],
        "description": job["description"],
        "status": job["status"],
        "created_at": job["created_at"],
        "updated_at": job["updated_at"],
        "requirements": job["requirements"],
    }
    jd = jd_key or job.get("jd_file")
    if jd:
        payload["jd_file"] = jd
    return payload


def _cv_payload(cv: dict) -> dict:
    keys = [
        "cv_id", "job_id", "file_name", "status", "candidate_name",
        "overall_score", "bucket", "recommendation", "explanation",
        "strengths", "weaknesses", "skill_gaps", "interview_questions",
        "skill_score", "experience_score", "education_score", "certification_score",
        "ranked_at", "rank",
    ]
    payload = {k: cv.get(k) for k in keys}
    payload["source"] = cv.get("source")
    payload["skills"] = cv.get("skills") or []
    payload["years_experience"] = cv.get("years_experience")
    payload["education"] = cv.get("education")
    payload["certifications"] = cv.get("certifications") or []
    payload["error"] = cv.get("error")
    payload["cv_id"] = cv.get("id") or cv.get("cv_id")
    return payload


def _bucket_from_score(overall: float) -> str:
    from app.ranking import bucket_for

    return bucket_for(overall)


def _json_dumps(value):
    import json

    return json.dumps(value) if value is not None else None
