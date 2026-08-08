from __future__ import annotations

from app.domain.errors import NotFoundError
from app.domain.import_job import (
    DOC_COMPLETED,
    DOC_FAILED,
    DOC_PROCESSING,
    DOC_UPLOADED,
    derive_import_status,
)
from app.repository.cv_repository import CvRepository
from app.repository.import_job_repository import ImportJobRepository
from app.repository.job_repository import JobRepository


class GetImportStatus:
    def __init__(
        self,
        repo: JobRepository,
        cv_repo: CvRepository,
        import_repo: ImportJobRepository,
    ):
        self.repo = repo
        self.cv_repo = cv_repo
        self.import_repo = import_repo

    async def execute(self, job_id: str, import_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        import_job = await self.import_repo.get(import_id)
        if import_job is None or import_job.job_id != job_id:
            raise NotFoundError("import_not_found")

        counts = await self.cv_repo.count_by_import(import_id)
        total = sum(counts.values())
        processed = counts.get(DOC_COMPLETED, 0)
        failed = counts.get(DOC_FAILED, 0)
        pending = (
            counts.get(DOC_UPLOADED, 0) + counts.get(DOC_PROCESSING, 0)
        )

        return {
            "import_id": import_job.id,
            "job_id": job_id,
            "status": derive_import_status(total, processed, failed),
            "total": total,
            "uploaded": total,
            "processed": processed,
            "failed": failed,
            "pending": pending,
            "created_at": import_job.created_at,
            "completed_at": import_job.completed_at,
        }
