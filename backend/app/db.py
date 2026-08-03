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
    updated_at    TEXT NOT NULL
);

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
    error               TEXT,
    source              TEXT
);

CREATE INDEX IF NOT EXISTS idx_cvs_job ON cvs(job_id);
"""


async def init_db() -> None:
    settings.ensure_dirs()
    async with aiosqlite.connect(settings.db_path) as db:
        await db.executescript(SCHEMA)
        try:
            await db.execute("ALTER TABLE cvs ADD COLUMN source TEXT")
        except sqlite3.OperationalError:
            pass  # column already exists
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
