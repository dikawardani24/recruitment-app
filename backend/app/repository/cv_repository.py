from __future__ import annotations

from typing import Protocol

from app.domain.candidate import Candidate
from app.domain.page import Page


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

    async def find_uploaded(self, limit: int) -> list[Candidate]:
        ...

    async def mark_processing(self, cv_id: str):
        ...

    async def reset_stale_processing(self):
        ...

    async def complete_document(self, candidate: Candidate):
        ...

    async def mark_failed(self, cv_id: str, error: str):
        ...

    async def count_by_import(self, import_id: str) -> dict[str, int]:
        ...

    async def search(
        self, keyword: str, page: int, page_size: int
    ) -> Page[Candidate]:
        ...
