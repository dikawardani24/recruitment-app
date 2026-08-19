import sqlite3
from collections.abc import AsyncIterator, Iterable
from contextlib import asynccontextmanager
from typing import Any

import aiosqlite

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

    def imports_scheme(self) -> str:
        return """
        CREATE TABLE IF NOT EXISTS import_jobs (
            id              TEXT PRIMARY KEY,
            job_id          TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
            total_files     INTEGER NOT NULL DEFAULT 0,
            uploaded_files  INTEGER NOT NULL DEFAULT 0,
            processed_files INTEGER NOT NULL DEFAULT 0,
            failed_files    INTEGER NOT NULL DEFAULT 0,
            status          TEXT NOT NULL DEFAULT 'uploading',
            created_at      TEXT NOT NULL,
            updated_at      TEXT NOT NULL,
            completed_at    TEXT
        );
        """

    def cvs_scheme(self) -> str:
        return """
        CREATE TABLE IF NOT EXISTS cvs (
            id                  TEXT PRIMARY KEY,
            job_id              TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
            import_job_id       TEXT REFERENCES import_jobs(id) ON DELETE SET NULL,
            file_name           TEXT NOT NULL,
            storage_path        TEXT NOT NULL,
            status              TEXT NOT NULL DEFAULT 'queued',
            created_at          TEXT NOT NULL DEFAULT '',
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
            source              TEXT,
            classification      TEXT,
            meets_job_description INTEGER,
            relevance_score     REAL
        );
        """

    def indexes_scheme(self) -> str:
        return """
        CREATE INDEX IF NOT EXISTS idx_cvs_job
        ON cvs(job_id);

        CREATE INDEX IF NOT EXISTS idx_cvs_import
        ON cvs(import_job_id);

        CREATE INDEX IF NOT EXISTS idx_import_jobs_job
        ON import_jobs(job_id);
        """

    async def init_scheme(self):
        settings.ensure_dirs()

        async with aiosqlite.connect(settings.db_path) as db:
            db.row_factory = sqlite3.Row
            await db.executescript(
                f"""
                {self.jobs_scheme()}

                {self.imports_scheme()}

                {self.cvs_scheme()}

                {self.indexes_scheme()}
                """
            )

            await self._migrate_cvs(db)
            await db.commit()

    @asynccontextmanager
    async def _connect(self) -> AsyncIterator[aiosqlite.Connection]:
        db = await aiosqlite.connect(settings.db_path)
        db.row_factory = sqlite3.Row
        await db.execute("PRAGMA busy_timeout = 10000")
        await db.execute("PRAGMA journal_mode = WAL")

        try:
            yield db
        finally:
            await db.close()

    async def _migrate_cvs(self, db) -> None:
        """Add ranking classification columns to pre-existing ``cvs`` tables."""
        cols = {row["name"] for row in await db.execute_fetchall("PRAGMA table_info(cvs)")}
        additions = {
            "classification": "TEXT",
            "meets_job_description": "INTEGER",
            "relevance_score": "REAL",
        }
        for col, decl in additions.items():
            if col not in cols:
                await db.execute(f"ALTER TABLE cvs ADD COLUMN {col} {decl}")

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