from __future__ import annotations

from dataclasses import dataclass

from app.database.entities.import_job_entity import ImportJobEntity


# Candidate document states (cvs.status).
DOC_UPLOADING = "uploading"
DOC_UPLOADED = "uploaded"
DOC_PROCESSING = "processing"
DOC_COMPLETED = "completed"
DOC_FAILED = "failed"

TERMINAL_DOC_STATUSES = (DOC_COMPLETED, DOC_FAILED)

# Import job states (import_jobs.status).
IMPORT_UPLOADING = "uploading"
IMPORT_SUBMITTED = "submitted"
IMPORT_PROCESSING = "processing"
IMPORT_COMPLETED = "completed"
IMPORT_PARTIALLY_FAILED = "partially_failed"
IMPORT_FAILED = "failed"


def derive_import_status(total: int, processed: int, failed: int) -> str:
    """Derive the import job state purely from its document counters."""
    if total <= 0:
        return IMPORT_UPLOADING
    pending = total - processed - failed
    if pending > 0:
        if processed == 0 and failed == 0:
            return IMPORT_SUBMITTED
        return IMPORT_PROCESSING
    if processed > 0 and failed == 0:
        return IMPORT_COMPLETED
    if processed > 0:
        return IMPORT_PARTIALLY_FAILED
    return IMPORT_FAILED


@dataclass
class ImportJob:
    id: str
    job_id: str
    total_files: int = 0
    uploaded_files: int = 0
    processed_files: int = 0
    failed_files: int = 0
    status: str = IMPORT_UPLOADING
    created_at: str = ""
    updated_at: str = ""
    completed_at: str | None = None

    def to_json(self) -> dict:
        return {
            "import_id": self.id,
            "job_id": self.job_id,
            "status": self.status,
            "total": self.total_files,
            "uploaded": self.uploaded_files,
            "processed": self.processed_files,
            "failed": self.failed_files,
            "created_at": self.created_at,
            "completed_at": self.completed_at,
        }

    @classmethod
    def from_entity(cls, entity: ImportJobEntity) -> "ImportJob":
        return cls(
            id=entity.id,
            job_id=entity.job_id,
            total_files=entity.total_files,
            uploaded_files=entity.uploaded_files,
            processed_files=entity.processed_files,
            failed_files=entity.failed_files,
            status=entity.status,
            created_at=entity.created_at,
            updated_at=entity.updated_at,
            completed_at=entity.completed_at,
        )

    def to_entity(self) -> ImportJobEntity:
        return ImportJobEntity(
            id=self.id,
            job_id=self.job_id,
            total_files=self.total_files,
            uploaded_files=self.uploaded_files,
            processed_files=self.processed_files,
            failed_files=self.failed_files,
            status=self.status,
            created_at=self.created_at,
            updated_at=self.updated_at,
            completed_at=self.completed_at,
        )
