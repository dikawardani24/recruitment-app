from __future__ import annotations

from app.database.db_client import DbClient
from app.database.entities.import_job_entity import ImportJobEntity


class ImportJobDatasource:

    def __init__(self, db: DbClient):
        self.db = db

    async def save(self, entity: ImportJobEntity):
        query = """
        INSERT INTO import_jobs (
            id,
            job_id,
            total_files,
            uploaded_files,
            processed_files,
            failed_files,
            status,
            created_at,
            updated_at,
            completed_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        await self.db.execute(
            query,
            (
                entity.id,
                entity.job_id,
                entity.total_files,
                entity.uploaded_files,
                entity.processed_files,
                entity.failed_files,
                entity.status,
                entity.created_at,
                entity.updated_at,
                entity.completed_at,
            ),
        )

    async def update(self, entity: ImportJobEntity):
        query = """
        UPDATE import_jobs
        SET
            total_files = ?,
            uploaded_files = ?,
            processed_files = ?,
            failed_files = ?,
            status = ?,
            updated_at = ?,
            completed_at = ?
        WHERE id = ?
        """
        await self.db.execute(
            query,
            (
                entity.total_files,
                entity.uploaded_files,
                entity.processed_files,
                entity.failed_files,
                entity.status,
                entity.updated_at,
                entity.completed_at,
                entity.id,
            ),
        )

    async def get(self, import_id: str) -> ImportJobEntity | None:
        query = """
        SELECT *
        FROM import_jobs
        WHERE id = ?
        """
        row = await self.db.fetchone(query, (import_id,))
        if row:
            return ImportJobEntity.from_row(row)
        return None

    async def find_by_job(self, job_id: str) -> list[ImportJobEntity]:
        query = """
        SELECT *
        FROM import_jobs
        WHERE job_id = ?
        ORDER BY created_at DESC
        """
        rows = await self.db.fetchall(query, (job_id,))
        return [ImportJobEntity.from_row(row) for row in rows]

    async def delete_by_job(self, job_id: str):
        query = """
        DELETE FROM import_jobs
        WHERE job_id = ?
        """
        await self.db.execute(query, (job_id,))
