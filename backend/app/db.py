from __future__ import annotations

import json
import sqlite3
from contextlib import asynccontextmanager
from typing import AsyncIterator

import aiosqlite

from app.config import settings

SCHEMA = """
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

CREATE INDEX IF NOT EXISTS idx_import_jobs_job ON import_jobs(job_id);

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
    source              TEXT
);

CREATE INDEX IF NOT EXISTS idx_cvs_job ON cvs(job_id);
CREATE INDEX IF NOT EXISTS idx_cvs_import ON cvs(import_job_id);
"""


async def _add_column(db, table: str, column: str, ddl: str) -> None:
    try:
        await db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}")
    except sqlite3.OperationalError:
        pass  # column already exists


async def init_db() -> None:
    settings.ensure_dirs()
    async with aiosqlite.connect(settings.db_path) as db:
        await db.executescript(SCHEMA)
        await _add_column(db, "cvs", "import_job_id", "TEXT REFERENCES import_jobs(id) ON DELETE SET NULL")
        await _add_column(db, "cvs", "created_at", "TEXT NOT NULL DEFAULT ''")
        await _add_column(db, "cvs", "source", "TEXT")
        await _add_column(db, "cvs", "ranked_by", "TEXT")
        await _add_column(db, "jobs", "jd_file", "TEXT")
        await db.commit()


@asynccontextmanager
async def connect() -> AsyncIterator[aiosqlite.Connection]:
    db = await aiosqlite.connect(settings.db_path)
    db.row_factory = sqlite3.Row
    try:
        yield db
    finally:
        await db.close()


def row_to_job(row) -> dict:
    job = dict(row)
    job["requirements"] = _loads(job.get("requirements"))
    return job


def row_to_cv(row) -> dict:
    cv = dict(row)
    for key in (
        "skills",
        "certifications",
        "strengths",
        "weaknesses",
        "skill_gaps",
        "interview_questions",
    ):
        cv[key] = _loads(cv.get(key))
    return cv


def _loads(value):
    if value is None:
        return None
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return None
