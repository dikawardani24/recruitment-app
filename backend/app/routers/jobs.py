from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app import db
from app.config import Settings
from app.jd import structure_jd
from app.llm import LLMRankingError, rank_with_llm
from app.llm_extract import extract_profile_text
from app.parsers import extract_text
from app.ranking import Profile, bucket_for, extract_profile, rule_reasoning, score_profile

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

    requirements = structure_jd(description) if description.strip() else None

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
            "INSERT INTO jobs (id, title, description, requirements, status, created_at, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                job["id"],
                job["title"],
                job["description"],
                _json_dumps(job["requirements"]),
                job["status"],
                job["created_at"],
                job["updated_at"],
            ),
        )
        await conn.commit()
    return {"job": _job_payload(job, jd_key=jd_key)}


@router.get("/jobs")
async def list_jobs() -> dict:
    async with db.connect() as conn:
        rows = await (await conn.execute("SELECT * FROM jobs ORDER BY created_at DESC")).fetchall()
    jobs = [db.row_to_job(r) for r in rows]
    return {"count": len(jobs), "jobs": [_job_payload(j) for j in jobs]}


@router.get("/jobs/{job_id}")
async def get_job(job_id: str) -> dict:
    job = await _require_job(job_id)
    return {"job": _job_payload(job)}


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

    profiles = [_profile_from_cv(cv) for cv in parsed]
    settings = _settings()
    scores_by_cv = {
        cv["id"]: score_profile(profiles[i], job["requirements"], settings)
        for i, cv in enumerate(parsed)
    }

    llm_rankings = None
    if settings.llm_enabled:
        try:
            llm_rankings = await rank_with_llm(
                settings,
                _flatten_requirements(job["requirements"]),
                [p.as_dict() for p in profiles],
            )
        except LLMRankingError:
            llm_rankings = None

    ranked = []
    if llm_rankings and len(llm_rankings) == len(parsed):
        for i, cv in enumerate(parsed):
            llm = llm_rankings[i]
            scores = scores_by_cv[cv["id"]]
            ranked.append(
                {
                    **cv,
                    "overall_score": llm.overall,
                    "bucket": bucket_for(llm.overall),
                    "recommendation": llm.recommendation,
                    "explanation": llm.explanation,
                    "strengths": llm.strengths,
                    "weaknesses": llm.weaknesses,
                    "skill_gaps": scores["missing_required"],
                    "skill_score": scores["skill_score"],
                    "experience_score": scores["experience_score"],
                    "education_score": scores["education_score"],
                    "certification_score": scores["certification_score"],
                    "ranked_at": _now(),
                }
            )
        ranked.sort(key=lambda c: c["overall_score"], reverse=True)
    else:
        for i, cv in enumerate(parsed):
            scores = scores_by_cv[cv["id"]]
            reasoning = rule_reasoning(profiles[i], job["requirements"], scores)
            ranked.append(
                {
                    **cv,
                    "overall_score": scores["overall"],
                    "bucket": bucket_for(scores["overall"]),
                    "recommendation": reasoning["recommendation"],
                    "explanation": reasoning["explanation"],
                    "strengths": reasoning["strengths"],
                    "weaknesses": reasoning["weaknesses"],
                    "skill_gaps": reasoning["skill_gaps"],
                    "skill_score": scores["skill_score"],
                    "experience_score": scores["experience_score"],
                    "education_score": scores["education_score"],
                    "certification_score": scores["certification_score"],
                    "ranked_at": _now(),
                }
            )
        ranked.sort(key=lambda c: c["overall_score"], reverse=True)

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
        "source": "llm" if llm_rankings else "rules",
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


def _profile_from_cv(cv: dict) -> Profile:
    return Profile(
        candidate_name=cv.get("candidate_name") or "Unknown Candidate",
        skills=cv.get("skills") or [],
        years_experience=cv.get("years_experience") or 0.0,
        education=cv.get("education"),
        certifications=cv.get("certifications") or [],
        profile_text=cv.get("profile_text") or "",
    )


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
    if jd_key:
        payload["jd_file"] = jd_key
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


def _flatten_requirements(req: dict) -> dict:
    return {
        "title": req.get("title"),
        "required_skills": req.get("required_skills"),
        "preferred_skills": req.get("preferred_skills"),
        "min_years": req.get("min_years"),
        "education": req.get("education"),
        "certifications": req.get("certifications"),
        "responsibilities": req.get("responsibilities"),
    }


def _bucket_from_score(overall: float) -> str:
    from app.ranking import bucket_for

    return bucket_for(overall)


def _json_dumps(value):
    import json

    return json.dumps(value) if value is not None else None
