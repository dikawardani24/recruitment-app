from __future__ import annotations

import asyncio
from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository


class UnifiedSearch:
    def __init__(self, job_repo: JobRepository, cv_repo: CvRepository):
        self.job_repo = job_repo
        self.cv_repo = cv_repo

    async def execute(self, keyword: str, limit: int = 5) -> dict:
        # Run both searches concurrently
        jobs_task = self.job_repo.search_jobs(keyword, page=1, page_size=limit)
        cvs_task = self.cv_repo.search(keyword=keyword, page=1, page_size=limit)

        jobs_page, cvs_page = await asyncio.gather(jobs_task, cvs_task)

        # Hydrate job counts (similar to GetJobByPage)
        job_ids = [job.id for job in jobs_page.data]
        counts = await self.cv_repo.count_by_job_ids(job_ids)

        jobs = []
        for job in jobs_page.data:
            payload = job.to_json()
            payload["cv_count"] = counts.get(job.id, 0)
            jobs.append(payload)

        candidates = [cv.to_json() for cv in cvs_page.data]

        return {
            "keyword": keyword,
            "jobs": {
                "data": jobs,
                "has_more": not jobs_page.last_page,
            },
            "candidates": {
                "data": candidates,
                "has_more": not cvs_page.last_page,
            },
        }
