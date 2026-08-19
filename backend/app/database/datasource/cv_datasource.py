from __future__ import annotations

from datetime import datetime, timezone

from app.database.db_client import DbClient
from app.database.entities.cv_entity import CvEntity


class CvDatasource:

    def __init__(self, db: DbClient):
        self.db = db

    async def save(self, entity: CvEntity):
        created_at = (
            entity.created_at
            or datetime.now(timezone.utc).isoformat()
        )
        query = """
        INSERT INTO cvs (
            id,
            job_id,
            import_job_id,
            file_name,
            storage_path,
            status,
            created_at,
            candidate_name,
            profile_text,
            skills,
            years_experience,
            education,
            certifications,
            source
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        await self.db.execute(
            query,
            (
                entity.id,
                entity.job_id,
                entity.import_job_id,
                entity.file_name,
                entity.storage_path,
                entity.status,
                created_at,
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
        classification: str | None = None,
        meets_job_description: bool | None = None,
        relevance_score: float | None = None,
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
            ranked_by = ?,
            classification = ?,
            meets_job_description = ?,
            relevance_score = ?
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
                classification,
                int(bool(meets_job_description)) if meets_job_description is not None else None,
                relevance_score,
                cv_id,
            ),
        )

    async def find_uploaded(self, limit: int) -> list[CvEntity]:
        query = """
        SELECT *
        FROM cvs
        WHERE status = 'uploaded'
        ORDER BY created_at ASC
        LIMIT ?
        """
        rows = await self.db.fetchall(query, (limit,))
        return [CvEntity.from_row(row) for row in rows]

    async def mark_processing(self, cv_id: str):
        query = """
        UPDATE cvs
        SET status = 'processing'
        WHERE id = ? AND status = 'uploaded'
        """
        await self.db.execute(query, (cv_id,))

    async def reset_stale_processing(self):
        query = """
        UPDATE cvs
        SET status = 'uploaded'
        WHERE status = 'processing'
        """
        await self.db.execute(query)

    async def complete_document(self, entity: CvEntity):
        query = """
        UPDATE cvs
        SET
            status = 'completed',
            candidate_name = ?,
            profile_text = ?,
            skills = ?,
            years_experience = ?,
            education = ?,
            certifications = ?,
            source = ?,
            error = NULL
        WHERE id = ?
        """
        await self.db.execute(
            query,
            (
                entity.candidate_name,
                entity.profile_text,
                entity.skills,
                entity.years_experience,
                entity.education,
                entity.certifications,
                entity.source,
                entity.id,
            ),
        )

    async def mark_failed(self, cv_id: str, error: str):
        query = """
        UPDATE cvs
        SET status = 'failed', error = ?
        WHERE id = ?
        """
        await self.db.execute(query, (error, cv_id))

    async def search(
        self, keyword: str, limit: int, offset: int
    ) -> list[CvEntity]:
        like = f"%{keyword}%"
        query = """
        SELECT *
        FROM cvs
        WHERE candidate_name LIKE ?
           OR skills LIKE ?
           OR file_name LIKE ?
           OR profile_text LIKE ?
        ORDER BY created_at DESC LIMIT ? OFFSET ?
        """
        rows = await self.db.fetchall(
            query, (like, like, like, like, limit, offset)
        )
        return [CvEntity.from_row(row) for row in rows]

    async def count_by_import(self, import_id: str) -> dict[str, int]:
        query = """
        SELECT status, COUNT(*) AS c
        FROM cvs
        WHERE import_job_id = ?
        GROUP BY status
        """
        rows = await self.db.fetchall(query, (import_id,))
        return {row["status"]: row["c"] for row in rows}
