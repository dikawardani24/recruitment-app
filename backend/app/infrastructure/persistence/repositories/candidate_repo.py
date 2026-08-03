from __future__ import annotations

from uuid import UUID

from app.core.ports import CandidateRepository as CandidateRepositoryPort
from app.domain.entities import Candidate


class CandidateRepository(CandidateRepositoryPort):
    """In-memory implementation for the skeleton.

    Phase 1 swaps this for a SQLAlchemy-backed repository via the same
    interface (the Container only depends on the port).
    """

    def __init__(self) -> None:
        self._store: dict[UUID, Candidate] = {}

    async def get(self, candidate_id: UUID) -> Candidate | None:
        return self._store.get(candidate_id)

    async def get_many(self, candidate_ids: list[UUID]) -> list[Candidate]:
        return [self._store[cid] for cid in candidate_ids if cid in self._store]

    async def save(self, candidate: Candidate) -> Candidate:
        self._store[candidate.id] = candidate
        return candidate

    async def delete(self, candidate_id: UUID) -> None:
        self._store.pop(candidate_id, None)
