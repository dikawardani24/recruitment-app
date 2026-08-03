from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from app.application.ranking.ranking_engine import SearchIntent, bucket_rank
from app.core.config import SearchSettings
from app.core.ports import CandidateRepository, EmbeddingProvider, VectorStore
from app.domain.entities import Candidate, CandidateRanking, VectorHit


@dataclass(frozen=True)
class SearchFilters:
    skills: list[str] | None = None
    min_years: float | None = None
    location: str | None = None
    sections: list[str] | None = None


class SearchCandidatesUseCase:
    def __init__(
        self,
        embedding: EmbeddingProvider,
        vector_store: VectorStore,
        candidate_repo: CandidateRepository,
        settings: SearchSettings,
    ) -> None:
        self._embedding = embedding
        self._vector_store = vector_store
        self._candidate_repo = candidate_repo
        self._settings = settings

    async def execute(
        self,
        query: str,
        *,
        filters: SearchFilters | None = None,
        top_k: int | None = None,
    ) -> list[tuple[Candidate, list[VectorHit]]]:
        qvec = self._embedding.embed_query(query)

        payload_filter: dict = {}
        if filters:
            if filters.skills:
                payload_filter["section"] = "skills"
            if filters.location:
                payload_filter["location"] = filters.location

        hits = await self._vector_store.search(qvec, filters=payload_filter, top_k=top_k or self._settings.top_k)

        grouped: dict[UUID, list[VectorHit]] = {}
        for h in hits:
            if h.score < self._settings.min_score:
                continue
            grouped.setdefault(h.candidate_id, []).append(h)

        ids = list(grouped.keys())
        candidates = await self._candidate_repo.get_many(ids)
        by_id = {c.id: c for c in candidates}

        result: list[tuple[Candidate, list[VectorHit]]] = []
        for cid, chits in grouped.items():
            cand = by_id.get(cid)
            if cand is not None:
                chits.sort(key=lambda h: h.score, reverse=True)
                result.append((cand, chits[:8]))
        return result
