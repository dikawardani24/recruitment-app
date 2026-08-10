from __future__ import annotations

from app.rag._indexer import EmbeddingIndexer
from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository


class ReindexEmbeddings:
    """Backfill/rebuild the vector index for all jobs (and their candidates), or
    a single job. Idempotent: re-indexing an entity replaces its points with the
    active embedding version. No-op when RAG is disabled."""

    def __init__(
        self,
        indexer: EmbeddingIndexer | None,
        job_repo: JobRepository,
        cv_repo: CvRepository,
    ):
        self.indexer = indexer
        self.job_repo = job_repo
        self.cv_repo = cv_repo

    async def execute(self, job_id: str | None = None, page_size: int = 100) -> dict:
        if self.indexer is None or not self.indexer.enabled:
            return {
                "enabled": False,
                "indexed_jobs": 0,
                "indexed_candidates": 0,
                "indexed_chunks": 0,
            }

        jobs = await self._collect_jobs(job_id, page_size)

        indexed_jobs = 0
        indexed_candidates = 0
        indexed_chunks = 0
        for job in jobs:
            indexed_chunks += await self.indexer.index_job(job)
            indexed_jobs += 1
            for candidate in await self.cv_repo.find_by_job(job.id):
                indexed_chunks += await self.indexer.index_candidate(candidate)
                indexed_candidates += 1

        return {
            "enabled": True,
            "indexed_jobs": indexed_jobs,
            "indexed_candidates": indexed_candidates,
            "indexed_chunks": indexed_chunks,
        }

    async def _collect_jobs(self, job_id: str | None, page_size: int) -> list:
        if job_id:
            job = await self.job_repo.get_by_id(job_id)
            return [job] if job else []

        jobs: list = []
        page = 1
        while True:
            result = await self.job_repo.get_job(page=page, page_size=page_size)
            jobs.extend(result.data)
            if result.last_page:
                break
            page += 1
        return jobs
