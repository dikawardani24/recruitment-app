from __future__ import annotations

from uuid import UUID

from app.application.ranking.ranking_engine import RankingEngine, SearchIntent, bucket_rank
from app.core.config import SearchSettings
from app.core.enums import RankingBucket
from app.core.ports import EmbeddingProvider, VectorStore
from app.domain.entities import Candidate, CandidateRanking, VectorHit


class RankCandidatesUseCase:
    """Orchestrates Tier-1 scoring + bucket assignment (doc 11).

    Tier-2 LLM reasoning is plugged in as a collaborator implementing
    the same interface, keeping this use case provider-agnostic.
    """

    def __init__(
        self,
        engine: RankingEngine,
        embedding: EmbeddingProvider,
        vector_store: VectorStore,
        settings: SearchSettings,
        reasoner=None,
    ) -> None:
        self._engine = engine
        self._embedding = embedding
        self._vector_store = vector_store
        self._settings = settings
        self._reasoner = reasoner

    async def rank(
        self,
        query: str,
        candidates: list[tuple[Candidate, list[VectorHit]]],
        intent: SearchIntent | None = None,
        job_id: UUID | None = None,
    ) -> list[CandidateRanking]:
        intent = intent or SearchIntent()
        results: list[CandidateRanking] = []

        for candidate, hits in candidates:
            scores = self._engine.compute_tier1(candidate, intent, hits)
            bucket = self._engine.assign_bucket(scores)

            ranking = CandidateRanking(
                candidate_id=candidate.id,
                candidate_name=candidate.name,
                bucket=RankingBucket(bucket),
                overall_score=scores.overall,
                skill_score=scores.skill,
                experience_score=scores.experience,
                education_score=scores.education,
                certification_score=scores.certification,
                evidence=hits,
            )

            if self._reasoner is not None:
                try:
                    reasoned = await self._reasoner.explain(candidate, intent, hits, ranking)
                    if reasoned is not None:
                        ranking = reasoned
                except Exception:
                    pass  # heuristic fallback keeps ranking valid

            results.append(ranking)

        results.sort(key=lambda r: (bucket_rank(r.bucket.value), -r.overall_score))
        return results
