from __future__ import annotations

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile

from app.di.injection import (
    saveJobUseCase,
    get_job_by_page_use_case,
    get_job_use_case,
    delete_job_use_case,
    import_cv_batch_use_case,
    list_cvs_use_case,
    get_import_status_use_case,
    delete_cv_use_case,
    rank_job_use_case,
    rank_cv_use_case,
    get_rankings_use_case,
)
from app.domain.errors import NotFoundError

router = APIRouter(tags=["jobs"])


@router.post("/jobs", status_code=201)
async def create_job(
    title: str = Form(...),
    description: str = Form(""),
    jd_file: UploadFile | None = File(None),
) -> dict:
    """Create a vacancy from pasted text and/or an uploaded JD file (PDF/DOCX/TXT)."""
    try:
        return await saveJobUseCase().execute(
            title=title,
            description=description,
            jd_file=jd_file,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/jobs")
async def list_jobs(
    page: int = Query(1, ge=1),
    limit: int = Query(20, alias="limit", ge=1, le=100),
) -> dict:
    return await get_job_by_page_use_case().execute(page=page, page_size=limit)


@router.get("/jobs/{job_id}")
async def get_job(job_id: str) -> dict:
    try:
        return await get_job_use_case().execute(job_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/jobs/{job_id}")
async def delete_job(job_id: str) -> dict:
    """Delete a job and everything attached to it: CVs, uploaded files, and JD."""
    try:
        return await delete_job_use_case().execute(job_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/jobs/{job_id}/cvs/{cv_id}")
async def delete_cv(job_id: str, cv_id: str) -> dict:
    """Delete a single candidate/CV from a job."""
    try:
        return await delete_cv_use_case().execute(job_id, cv_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/jobs/{job_id}/candidates/import", status_code=202)
async def import_cvs_batch(
    job_id: str,
    files: list[UploadFile] = File(...),
    import_id: str | None = Form(None),
) -> dict:
    """Upload one batch of CV files. Files are persisted and queued for
    background processing; this call returns immediately and does not wait for
    extraction/AI. Pass an existing `import_id` to append to an ongoing import."""
    try:
        return await import_cv_batch_use_case().execute(
            job_id, files, import_id=import_id
        )
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/jobs/{job_id}/cvs", status_code=202)
async def upload_cvs(
    job_id: str,
    files: list[UploadFile] = File(...),
    import_id: str | None = Form(None),
) -> dict:
    """Backwards-compatible alias for `POST /jobs/{job_id}/candidates/import`."""
    try:
        return await import_cv_batch_use_case().execute(
            job_id, files, import_id=import_id
        )
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/jobs/{job_id}/imports/{import_id}")
async def get_import_status(job_id: str, import_id: str) -> dict:
    """Import progress: total/uploaded/processed/failed counts and state."""
    try:
        return await get_import_status_use_case().execute(job_id, import_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/jobs/{job_id}/cvs")
async def list_cvs(job_id: str) -> dict:
    try:
        return await list_cvs_use_case().execute(job_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/jobs/{job_id}/rank")
async def rank_job(job_id: str) -> dict:
    """Score + rank every parsed CV, with reasoning (LLM when configured, else rules)."""
    try:
        return await rank_job_use_case().execute(job_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/jobs/{job_id}/cvs/{cv_id}/rank")
async def rank_cv(job_id: str, cv_id: str) -> dict:
    """Score + rank a single CV against the job's requirements."""
    try:
        return await rank_cv_use_case().execute(job_id, cv_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/jobs/{job_id}/rankings")
async def get_rankings(job_id: str) -> dict:
    try:
        return await get_rankings_use_case().execute(job_id)
    except NotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
