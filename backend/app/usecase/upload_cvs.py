from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from app.config import Settings
from app.domain.candidate import Candidate
from app.domain.errors import NotFoundError
from app.extraction import extract_profile_text
from app.parsers import extract_text
from app.repository.job_repository import JobRepository
from app.repository.cv_repository import CvRepository
from app.util.file_util import save_file


class UploadCvs:
    def __init__(
        self,
        repo: JobRepository,
        cv_repo: CvRepository,
        settings: Settings,
    ):
        self.repo = repo
        self.cv_repo = cv_repo
        self.settings = settings

    async def execute(self, job_id: str, files: list[UploadFile]) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        results = []
        for file in files:
            name = file.filename or "unnamed"
            content = await file.read()
            try:
                text = await extract_text(name, content)
                profile, source = await extract_profile_text(
                    self.settings, text, name
                )
                storage = save_file(
                    self.settings.upload_dir,
                    Path(name).suffix.lower(),
                    content,
                )
                cv_id = str(uuid4())
                candidate = Candidate(
                    id=cv_id,
                    job_id=job_id,
                    file_name=name,
                    storage_path=storage,
                    status="parsed",
                    candidate_name=profile.candidate_name,
                    profile_text=text,
                    skills=profile.skills,
                    years_experience=profile.years_experience,
                    education=profile.education,
                    certifications=profile.certifications,
                    source=source,
                )
                await self.cv_repo.save(candidate)
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
                    {
                        "cv_id": None,
                        "file_name": name,
                        "status": "failed",
                        "candidate_name": None,
                        "error": str(exc),
                    }
                )
        return {"job_id": job_id, "uploaded": len(results), "results": results}
