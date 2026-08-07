from __future__ import annotations

from app.database.db_client import DbClient
from app.database.entities.cv_entity import CvEntity


class CvDatasource:

    def __init__(self, db: DbClient):
        self.db = db

    async def save(self, entity: CvEntity):
        query = """
        INSERT INTO cvs (
            id,
            job_id,
            file_name,
            storage_path,
            status,
            candidate_name,
            profile_text,
            skills,
            years_experience,
            education,
            certifications,
            source
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        await self.db.execute(
            query,
            (
                entity.id,
                entity.job_id,
                entity.file_name,
                entity.storage_path,
                entity.status,
                entity.candidate_name,
                entity.profile_text,
                entity.skills,
                entity.years_experience,
                entity.education,
                entity.certifications,
                entity.source,
            ),
        )

    async def find_by_job(self, job_id: str) -> list[CvEntity]:
        query = """
        SELECT *
        FROM cvs
        WHERE job_id = ?
        """
        rows = await self.db.fetchall(query, (job_id,))
        return [CvEntity.from_row(row) for row in rows]

    async def find_by_id(self, job_id: str, cv_id: str) -> CvEntity | None:
        query = """
        SELECT *
        FROM cvs
        WHERE id = ? AND job_id = ?
        """
        row = await self.db.fetchone(query, (cv_id, job_id))
        if row:
            return CvEntity.from_row(row)
        return None

    async def delete(self, job_id: str, cv_id: str):
        query = """
        DELETE FROM cvs
        WHERE id = ? AND job_id = ?
        """
        await self.db.execute(query, (cv_id, job_id))

    async def delete_by_job(self, job_id: str):
        query = """
        DELETE FROM cvs
        WHERE job_id = ?
        """
        await self.db.execute(query, (job_id,))

    async def count_by_job_ids(self, job_ids: list[str]) -> dict[str, int]:
        if not job_ids:
            return {}
        placeholders = ",".join("?" for _ in job_ids)
        query = f"""
        SELECT job_id, COUNT(*) AS c
        FROM cvs
        WHERE job_id IN ({placeholders})
        GROUP BY job_id
        """
        rows = await self.db.fetchall(query, tuple(job_ids))
        return {row["job_id"]: row["c"] for row in rows}

    async def update_ranked(
        self,
        cv_id: str,
        *,
        overall_score: float | None,
        bucket: str | None,
        recommendation: str | None,
        explanation: str | None,
        strengths: str | None,
        weaknesses: str | None,
        skill_gaps: str | None,
        skill_score: float | None,
        experience_score: float | None,
        education_score: float | None,
        certification_score: float | None,
        ranked_at: str | None,
        ranked_by: str | None,
    ):
        query = """
        UPDATE cvs
        SET
            status = 'ranked',
            overall_score = ?,
            bucket = ?,
            recommendation = ?,
            explanation = ?,
            strengths = ?,
            weaknesses = ?,
            skill_gaps = ?,
            skill_score = ?,
            experience_score = ?,
            education_score = ?,
            certification_score = ?,
            ranked_at = ?,
            ranked_by = ?
        WHERE id = ?
        """
        await self.db.execute(
            query,
            (
                overall_score,
                bucket,
                recommendation,
                explanation,
                strengths,
                weaknesses,
                skill_gaps,
                skill_score,
                experience_score,
                education_score,
                certification_score,
                ranked_at,
                ranked_by,
                cv_id,
            ),
        )
