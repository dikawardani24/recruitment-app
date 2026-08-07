from contextlib import asynccontextmanager
from collections.abc import AsyncIterator, Iterable
from typing import Any

import aiosqlite
import sqlite3

from app.config import settings


class DbClient:

    def jobs_scheme(self) -> str:
        return """
        CREATE TABLE IF NOT EXISTS jobs (
            id            TEXT PRIMARY KEY,
            title         TEXT NOT NULL,
            description   TEXT NOT NULL DEFAULT '',
            requirements  TEXT,
            status        TEXT NOT NULL DEFAULT 'draft',
            created_at    TEXT NOT NULL,
            updated_at    TEXT NOT NULL,
            jd_file       TEXT
        );
        """

    def cvs_scheme(self) -> str:
        return """
        CREATE TABLE IF NOT EXISTS cvs (
            id                  TEXT PRIMARY KEY,
            job_id              TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
            file_name           TEXT NOT NULL,
            storage_path        TEXT NOT NULL,
            status              TEXT NOT NULL DEFAULT 'queued',
            candidate_name      TEXT,
            profile_text        TEXT,
            skills              TEXT,
            years_experience    REAL,
            education           TEXT,
            certifications      TEXT,
            overall_score       REAL,
            bucket              TEXT,
            recommendation      TEXT,
            skill_score         REAL,
            experience_score    REAL,
            education_score     REAL,
            certification_score REAL,
            strengths           TEXT,
            weaknesses          TEXT,
            skill_gaps          TEXT,
            explanation         TEXT,
            interview_questions TEXT,
            ranked_at           TEXT,
            ranked_by           TEXT,
            error               TEXT,
            source              TEXT
        );
        """

    def indexes_scheme(self) -> str:
        return """
        CREATE INDEX IF NOT EXISTS idx_cvs_job
        ON cvs(job_id);
        """

    async def init_scheme(self):
        settings.ensure_dirs()

        async with aiosqlite.connect(settings.db_path) as db:
            await db.executescript(
                f"""
                {self.jobs_scheme()}

                {self.cvs_scheme()}

                {self.indexes_scheme()}
                """
            )

            await db.commit()

    @asynccontextmanager
    async def _connect(self) -> AsyncIterator[aiosqlite.Connection]:
        db = await aiosqlite.connect(settings.db_path)
        db.row_factory = sqlite3.Row

        try:
            yield db
        finally:
            await db.close()

    async def execute(
        self,
        query: str,
        parameters: Iterable[Any] = (),
    ) -> int:
        async with self._connect() as db:
            cursor = await db.execute(query, tuple(parameters))
            await db.commit()
            return cursor.rowcount

    async def executemany(
        self,
        query: str,
        parameters: Iterable[Iterable[Any]],
    ):
        async with self._connect() as db:
            await db.executemany(query, parameters)
            await db.commit()

    async def fetchone(
        self,
        query: str,
        parameters: Iterable[Any] = (),
    ) -> sqlite3.Row | None:
        async with self._connect() as db:
            cursor = await db.execute(query, tuple(parameters))
            return await cursor.fetchone()

    async def fetchall(
        self,
        query: str,
        parameters: Iterable[Any] = (),
    ) -> list[sqlite3.Row]:
        async with self._connect() as db:
            cursor = await db.execute(query, tuple(parameters))
            return await cursor.fetchall()