from __future__ import annotations

from dataclasses import dataclass

import sqlite3


@dataclass
class ImportJobEntity:
    id: str
    job_id: str
    total_files: int = 0
    uploaded_files: int = 0
    processed_files: int = 0
    failed_files: int = 0
    status: str = "uploading"
    created_at: str = ""
    updated_at: str = ""
    completed_at: str | None = None

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "ImportJobEntity":
        return cls(
            id=row["id"],
            job_id=row["job_id"],
            total_files=row["total_files"],
            uploaded_files=row["uploaded_files"],
            processed_files=row["processed_files"],
            failed_files=row["failed_files"],
            status=row["status"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            completed_at=row["completed_at"],
        )
