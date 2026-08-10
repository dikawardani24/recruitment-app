from __future__ import annotations

from typing import Protocol

from app.domain.job import Job
from app.domain.page import Page
from app.database.datasource.job_datasource import JobDatasource

class JobRepository(Protocol):

    async def save(self, job: Job):
        ...

    async def get_job(self, page: int, page_size: int)-> Page[Job]:
        ...

    async def search_jobs(self, keyword: str, page: int, page_size: int) -> Page[Job]:
        ...

    async def get_by_id(self, job_id: str) -> Job | None:
        ...

    async def delete(self, job_id: str):
        ...