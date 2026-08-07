from __future__ import annotations

from typing import Protocol

from app.domain.candidate import Candidate


class CvRepository(Protocol):

    async def save(self, candidate: Candidate):
        ...

    async def find_by_job(self, job_id: str) -> list[Candidate]:
        ...

    async def find_by_id(self, job_id: str, cv_id: str) -> Candidate | None:
        ...

    async def delete(self, job_id: str, cv_id: str):
        ...

    async def delete_by_job(self, job_id: str):
        ...

    async def count_by_job_ids(self, job_ids: list[str]) -> dict[str, int]:
        ...

    async def update_ranked(self, candidate: Candidate):
        ...
