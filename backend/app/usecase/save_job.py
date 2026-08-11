from __future__ import annotations

import contextlib
import json
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from app.config import settings
from app.domain.job import Job
from app.jd import RequirementParser
from app.parsers import extract_text
from app.rag._indexer import EmbeddingIndexer
from app.repository.job_repository import JobRepository
from app.util.date_util import now


class SaveJob:
    def __init__(self, repo: JobRepository, indexer: EmbeddingIndexer | None = None):
        self.repo = repo
        self.indexer = indexer

    async def execute(
        self,
        title: str,
        description: str = "",
        jd_file: UploadFile | None = None,
    ) -> dict:
        title = title.strip()
        if not title:
            raise ValueError("job_title_required")

        jd_bytes = await jd_file.read() if jd_file else None
        jd_key = None
        if jd_bytes:
            jd_text = await extract_text(jd_file.filename or "job.txt", jd_bytes)
            if not description.strip():
                description = jd_text
            suffix = Path(jd_file.filename or "job.txt").suffix.lower()
            jd_key = _save_file(settings.upload_dir / "jd", suffix, jd_bytes)

        # If description is valid JSON, normalize it into requirements.
        # Otherwise, parse it as plain text with structure_jd().
        # Always keep the original description text for display.
        parser = RequirementParser()
        requirements = parser.parse(description) if description.strip() else None

        job = Job(
            id=str(uuid4()),
            title=title,
            desc=description.strip(),
            req=_json_dumps(requirements),
            status="open",
            created_at=now(),
            updated_at=now(),
            jd_file_path=jd_key,
        )
        if not job.is_data_valid():
            raise ValueError("Job data is not valid")

        await self.repo.save(job)
        await self._index(job)

        return {"job": job.to_json()}

    async def _index(self, job: Job) -> None:
        # Best-effort: a failure to embed must not break job creation; run
        # POST /api/search/reindex to repair the index.
        if self.indexer is None or not self.indexer.enabled:
            return
        with contextlib.suppress(Exception):
            await self.indexer.index_job(job)


def _save_file(upload_dir: Path, suffix: str, content: bytes) -> str:
    upload_dir.mkdir(parents=True, exist_ok=True)
    path = upload_dir / f"{uuid4().hex}{suffix}"
    path.write_bytes(content)
    return str(path)


def _json_dumps(value) -> str | None:
    return json.dumps(value) if value is not None else None
