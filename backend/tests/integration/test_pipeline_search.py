from __future__ import annotations

import os
from dataclasses import replace
from uuid import UUID, uuid4

import pytest

os.environ["ATS_EMBEDDING__PROVIDER"] = "debug"

from app.core.ports import VectorStore
from app.domain.entities import SemanticChunk, VectorHit


class InMemoryVectorStore(VectorStore):
    """Port-compatible fake so tests run without Qdrant (doc 05 testing strategy)."""

    def __init__(self) -> None:
        self._chunks: list[SemanticChunk] = []

    async def ensure_collection(self) -> None:
        pass

    async def upsert(self, chunks: list[SemanticChunk], model: str, version: int) -> None:
        self._chunks.extend(chunks)

    async def search(
        self,
        query_embedding: list[float],
        *,
        filters: dict | None = None,
        top_k: int = 50,
    ) -> list[VectorHit]:
        hits = []
        for c in self._chunks:
            if filters and filters.get("section") and c.section.value != filters["section"]:
                continue
            score = 0.9 if "Flutter" in c.text or "flutter" in c.text else 0.3
            hits.append(
                VectorHit(
                    chunk_id=c.id,
                    candidate_id=c.candidate_id,
                    candidate_name=c.candidate_name,
                    resume_id=c.resume_id,
                    section=c.section,
                    text=c.text,
                    score=score,
                )
            )
        hits.sort(key=lambda h: h.score, reverse=True)
        return hits[:top_k]

    async def delete_by_candidate(self, candidate_id: UUID, version: int | None = None) -> None:
        self._chunks = [c for c in self._chunks if c.candidate_id != candidate_id]

    async def delete_by_resume(self, resume_id: UUID, version: int | None = None) -> None:
        self._chunks = [c for c in self._chunks if c.resume_id != resume_id]


async def _seed_candidate(container, skills: list[str], position: str = "Senior Flutter Engineer") -> None:
    from app.core.enums import Section
    from app.domain.entities import Candidate, CandidateProfile, Education, Experience, SemanticChunk

    cand = Candidate(
        id=uuid4(),
        name="Jane Doe",
        email=None,
        phone=None,
        location="Berlin",
        summary="Flutter engineer with banking experience",
        profile=CandidateProfile(
            candidate={"name": "Jane Doe"},
            summary="Flutter engineer with banking experience",
            skills=skills,
            experience=[
                Experience(
                    company="BankCo",
                    position=position,
                    start_date="2018-01",
                    end_date=None,
                    responsibilities=["Led payments squad"],
                )
            ],
            education=[Education(institution="TU Berlin", degree="BSc", field="CS")],
        ),
    )
    await container.candidate_repo.save(cand)

    resume_id = uuid4()
    chunks = [
        SemanticChunk(
            id=uuid4(),
            candidate_id=cand.id,
            candidate_name=cand.name,
            resume_id=resume_id,
            section=Section.SKILLS,
            text="Skills — " + ", ".join(skills),
            version=1,
            embedding_model="debug-hash",
        ),
        SemanticChunk(
            id=uuid4(),
            candidate_id=cand.id,
            candidate_name=cand.name,
            resume_id=resume_id,
            section=Section.EXPERIENCE,
            text=f"Experience — BankCo\n{position} (2018-01 to Present)\n• Led payments squad",
            version=1,
            embedding_model="debug-hash",
        ),
    ]
    await container.vector_store.upsert(chunks, "debug-hash", 1)


@pytest.mark.asyncio
async def test_search_rank_end_to_end():
    from app.application.ranking.ranking_engine import RankingEngine
    from app.application.use_cases.ranking.rank_candidates import RankCandidatesUseCase
    from app.application.use_cases.search.intent_parser import IntentParser
    from app.application.use_cases.search.search_candidates import SearchCandidatesUseCase
    from app.core.container import Container

    container = Container()
    container.vector_store = InMemoryVectorStore()

    await _seed_candidate(container, ["flutter", "dart", "firebase"])
    await _seed_candidate(container, ["kubernetes", "terraform"], position="DevOps Engineer")

    search_uc = SearchCandidatesUseCase(
        embedding=container.embedding,
        vector_store=container.vector_store,
        candidate_repo=container.candidate_repo,
        settings=container.settings.search,
    )
    results = await search_uc.execute("Find Senior Flutter Developers with banking experience", top_k=20)
    assert results, "expected retrieved candidates"

    intent = IntentParser().parse("Find Senior Flutter Developers with banking experience")
    intent = replace(intent, required_skills=["flutter", "dart"])

    engine = RankingEngine(container.settings.ranking, container.years_calculator)
    ranker = RankCandidatesUseCase(
        engine=engine,
        embedding=container.embedding,
        vector_store=container.vector_store,
        settings=container.settings.search,
        reasoner=None,  # heuristic tier only (LLM reasoner covered by unit tests)
    )
    rankings = await ranker.rank("Find Senior Flutter Developers with banking experience", results, intent=intent)

    assert rankings, "expected ranked candidates"
    assert rankings[0].candidate_name == "Jane Doe"
    assert rankings[0].bucket.value in {"best", "strong", "hidden_gem"}
    assert rankings[0].overall_score >= 0.5
