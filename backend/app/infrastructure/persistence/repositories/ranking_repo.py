from __future__ import annotations

from uuid import UUID

from app.core.ports import RankingRepository as RankingRepositoryPort
from app.domain.entities import CandidateRanking


class RankingRepository(RankingRepositoryPort):
    """In-memory implementation for the skeleton (persisted via SQL in Phase 2)."""

    def __init__(self) -> None:
        self._store: dict[UUID, list[CandidateRanking]] = {}

    async def save(self, ranking: CandidateRanking) -> None:
        self._store.setdefault(ranking.candidate_id, []).append(ranking)

    async def list_by_job(self, job_id: UUID) -> list[CandidateRanking]:
        return [r for rows in self._store.values() for r in rows]
