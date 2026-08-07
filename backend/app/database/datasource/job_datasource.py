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
            entity.updated_at
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
                entity.description,
                entity.requirements,
                entity.status,
                entity.updated_at,
                entity.jd_file,
                entity.id,
            ),
        )

    async def find_by_id(self, job_id: str):
        query = """
        SELECT *
        FROM jobs
        WHERE id = ?
        """

        return await self.db.fetchone(query, (job_id,))

    async def find_all(self):
        query = """
        SELECT *
        FROM jobs
        ORDER BY created_at DESC
        """

        return await self.db.fetchall(query)

    async def delete(self, job_id: str):
        query = """
        DELETE FROM jobs
        WHERE id = ?
        """

        await self.db.execute(query, (job_id,))