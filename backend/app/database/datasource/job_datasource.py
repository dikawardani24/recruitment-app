from __future__ import annotations

from app.database.db_client import DbClient
from app.database.entities.job_entity import JobEntity


class JobDatasource:

    def __init__(self, db: DbClient):
        self.db = db

    async def save(self, entity: JobEntity):
        query = """
        INSERT INTO jobs (
            id,
            title,
            description,
            requirements,
            status,
            created_at,
            updated_at,
            jd_file
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        param = (
            entity.id,
            entity.title,
            entity.desc,
            entity.req,
            entity.status,
            entity.created_at,
            entity.updated_at,
            entity.jd_file_path
        )
        await self.db.execute(query, parameters=param)

    async def update(self, entity: JobEntity):
        query = """
        UPDATE jobs
        SET
            title = ?,
            description = ?,
            requirements = ?,
            status = ?,
            updated_at = ?,
            jd_file = ?
        WHERE id = ?
        """

        await self.db.execute(
            query,
            (
                entity.title,
                entity.desc,
                entity.req,
                entity.status,
                entity.updated_at,
                entity.jd_file_path,
                entity.id,
            ),
        )

    async def find_by_id(self, job_id: str) -> JobEntity | None:
        query = """
        SELECT *
        FROM jobs
        WHERE id = ?
        """

        data = await self.db.fetchone(query, (job_id,))
        if data:
            return JobEntity.from_row(data)
        return None
        

    async def find_all(self) -> list[JobEntity]:
        query = """
        SELECT *
        FROM jobs
        ORDER BY created_at DESC
        """

        list_data = await self.db.fetchall(query)
        return [JobEntity.from_row(row) for row in list_data]

    async def delete(self, job_id: str):
        query = """
        DELETE FROM jobs
        WHERE id = ?
        """

        await self.db.execute(query, (job_id,))

    async def find_by_limit_and_offset(self, limit: int, offset: int)-> list[JobEntity]:
        query = """
        SELECT * FROM jobs ORDER BY created_at DESC LIMIT ? OFFSET ?
        """
        list_data = await self.db.fetchall(query, (limit, offset))
        return [JobEntity.from_row(row) for row in list_data]
