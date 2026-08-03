from __future__ import annotations

from fastapi import APIRouter, Depends

from app.application.use_cases.search.intent_parser import IntentParser
from app.application.use_cases.search.search_candidates import SearchCandidatesUseCase, SearchFilters
from app.core.container import Container
from app.core.ports import LLMProvider

router = APIRouter(tags=["search"])


def get_container() -> Container:
    return Container()


@router.post("/search/query")
async def search_candidates(
    body: dict,
    container: Container = Depends(get_container),
) -> dict:
    query: str = body.get("query", "")
    use_case: SearchCandidatesUseCase = container.search_candidates_use_case()

    filters_dict = body.get("filters") or {}
    filters = SearchFilters(
        skills=filters_dict.get("skills"),
        min_years=filters_dict.get("min_years"),
        location=filters_dict.get("location"),
        sections=filters_dict.get("sections"),
    )

    results = await use_case.execute(query, filters=filters, top_k=body.get("top_k"))
    intent = IntentParser().parse(query)
    intent.required_skills = IntentParser().extract_skills(query, _known_skills(container))

    engine = _build_engine(container)
    rankings = await _rank(container, engine, query, results, intent)

    return {
        "query": query,
        "count": len(rankings),
        "results": [
            {
                "candidate_id": str(r.candidate_id),
                "candidate_name": r.candidate_name,
                "bucket": r.bucket.value,
                "overall_score": r.overall_score,
                "scores": {
                    "skill_match": r.skill_score,
                    "experience_match": r.experience_score,
                    "education_match": r.education_score,
                    "certification_match": r.certification_score,
                },
                "explanation": r.explanation,
                "evidence": [
                    {"chunk_id": str(h.chunk_id), "section": h.section.value, "score": h.score, "text": h.text[:300]}
                    for h in r.evidence
                ],
            }
            for r in rankings
        ],
    }


def _known_skills(container: Container) -> list[str]:
    return list(container.skill_normalizer._seen.keys())  # noqa: SLF001  (populated at index time)


def _build_engine(container: Container):
    from app.application.ranking.ranking_engine import RankingEngine

    return RankingEngine(container.settings.ranking, container.years_calculator)


async def _rank(container: Container, engine, query, results, intent):
    from app.application.use_cases.ranking.rank_candidates import RankCandidatesUseCase

    reasoner = None
    try:
        llm: LLMProvider = container.llm
        from app.application.ranking.llm_reasoner import EvidenceConstrainedReasoner

        reasoner = EvidenceConstrainedReasoner(llm)
    except Exception:
        reasoner = None

    use_case = RankCandidatesUseCase(
        engine=engine,
        embedding=container.embedding,
        vector_store=container.vector_store,
        settings=container.settings.search,
        reasoner=reasoner,
    )
    return await use_case.rank(query, results, intent=intent)
