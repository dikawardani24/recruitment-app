from __future__ import annotations

from typing import Protocol

from app.domain.import_job import ImportJob


class ImportJobRepository(Protocol):

    async def create(self, import_job: ImportJob):
        ...

    async def update(self, import_job: ImportJob):
        ...

    async def get(self, import_id: str) -> ImportJob | None:
        ...

    async def find_by_job(self, job_id: str) -> list[ImportJob]:
        ...

    async def delete_by_job(self, job_id: str):
        ...
