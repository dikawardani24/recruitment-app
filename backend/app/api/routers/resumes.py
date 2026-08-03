from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, File, UploadFile

from app.core.container import Container
from app.core.ports import ResumeRepository

router = APIRouter(tags=["resumes"])


def get_container() -> Container:
    return Container()


@router.post("/resumes/upload", status_code=202)
async def upload_resume(
    file: UploadFile = File(...),
    container: Container = Depends(get_container),
) -> dict:
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise ValueError("invalid_file_type")
    content = await file.read()
    resume, created = await container.upload_resume_use_case().execute(file.filename, content)
    return {
        "resume_id": str(resume.id),
        "status": resume.status.value,
        "created": created,
        "poll_url": f"/v1/resumes/{resume.id}",
    }


@router.get("/resumes/{resume_id}")
async def get_resume(
    resume_id: UUID,
    container: Container = Depends(get_container),
) -> dict:
    repo: ResumeRepository = container.resume_repo
    resume = await repo.get(resume_id)
    if resume is None:
        return {"resume_id": str(resume_id), "status": "not_found"}
    return {
        "resume_id": str(resume.id),
        "candidate_id": str(resume.candidate_id) if resume.candidate_id else None,
        "status": resume.status.value,
        "file_name": resume.file_name,
        "embedding_model": resume.embedding_model,
        "embedding_version": resume.embedding_version,
        "parsing_meta": resume.parsing_meta,
        "error_detail": resume.error_detail,
    }
