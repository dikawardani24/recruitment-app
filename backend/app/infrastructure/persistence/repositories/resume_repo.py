from __future__ import annotations

from uuid import UUID

from app.core.ports import ResumeRepository as ResumeRepositoryPort
from app.domain.entities import Resume


class ResumeRepository(ResumeRepositoryPort):
    """In-memory implementation for the skeleton (swapped for SQL in Phase 1)."""

    def __init__(self) -> None:
        self._store: dict[UUID, Resume] = {}

    async def get(self, resume_id: UUID) -> Resume | None:
        return self._store.get(resume_id)

    async def save(self, resume: Resume) -> Resume:
        self._store[resume.id] = resume
        return resume

    async def create(self, resume: Resume) -> Resume:
        return await self.save(resume)

    async def get_by_candidate(self, candidate_id: UUID) -> list[Resume]:
        return [r for r in self._store.values() if r.candidate_id == candidate_id]

    async def get_by_hash(self, sha256: str) -> Resume | None:
        for r in self._store.values():
            if r.parsing_meta.get("sha256") == sha256:
                return r
        return None
