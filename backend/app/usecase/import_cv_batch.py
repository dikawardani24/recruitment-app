from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from app.config import Settings
from app.domain.candidate import Candidate
from app.domain.errors import NotFoundError
from app.domain.import_job import (
    DOC_UPLOADED,
    IMPORT_UPLOADING,
    ImportJob,
    derive_import_status,
)
from app.repository.cv_repository import CvRepository
from app.repository.import_job_repository import ImportJobRepository
from app.repository.job_repository import JobRepository
from app.util.file_util import save_file


class ImportCvBatch:
    """Upload one batch of CV files.

    Files are persisted immediately and each becomes a queued document. The
    HTTP request returns as soon as the batch is stored; CV extraction and
    profile building happen in the background (see app.imports.CvProcessor).
    """

    def __init__(
        self,
        repo: JobRepository,
        cv_repo: CvRepository,
        import_repo: ImportJobRepository,
        settings: Settings,
    ):
        self.repo = repo
        self.cv_repo = cv_repo
        self.import_repo = import_repo
        self.settings = settings

    async def execute(
        self,
        job_id: str,
        files: list[UploadFile],
        import_id: str | None = None,
    ) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        now = datetime.now(timezone.utc).isoformat()
        if import_id:
            import_job = await self.import_repo.get(import_id)
            if import_job is None or import_job.job_id != job_id:
                raise NotFoundError("import_not_found")
        else:
            import_job = ImportJob(
                id=str(uuid4()),
                job_id=job_id,
                status=IMPORT_UPLOADING,
                created_at=now,
                updated_at=now,
            )
            await self.import_repo.create(import_job)

        batch_files = 0
        for file in files:
            name = file.filename or "unnamed"
            content = await file.read()
            storage = save_file(
                self.settings.upload_dir,
                Path(name).suffix.lower(),
                content,
            )
            await self.cv_repo.save(
                Candidate(
                    id=str(uuid4()),
                    job_id=job_id,
                    import_job_id=import_job.id,
                    file_name=name,
                    storage_path=storage,
                    status=DOC_UPLOADED,
                    created_at=now,
                )
            )
            batch_files += 1

        counts = await self.cv_repo.count_by_import(import_job.id)
        total = sum(counts.values())
        import_job.total_files = total
        import_job.uploaded_files = total
        import_job.status = derive_import_status(total, 0, 0)
        import_job.updated_at = now
        await self.import_repo.update(import_job)

        return {
            "import_id": import_job.id,
            "job_id": job_id,
            "status": import_job.status,
            "total_files": total,
            "batch_files": batch_files,
        }
