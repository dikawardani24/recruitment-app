from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends

from app.core.container import Container
from app.core.ports import CandidateRepository

router = APIRouter(tags=["candidates"])


def get_container() -> Container:
    return Container()


@router.get("/candidates")
async def list_candidates(
    container: Container = Depends(get_container),
) -> dict:
    repo: CandidateRepository = container.candidate_repo
    return {"data": []}  # paginated list — implemented in Phase 2


@router.get("/candidates/{candidate_id}")
async def get_candidate(
    candidate_id: UUID,
    container: Container = Depends(get_container),
) -> dict:
    repo: CandidateRepository = container.candidate_repo
    candidate = await repo.get(candidate_id)
    if candidate is None:
        return {"candidate_id": str(candidate_id), "found": False}
    return {
        "candidate_id": str(candidate.id),
        "name": candidate.name,
        "location": candidate.location,
        "summary": candidate.summary,
        "skills": candidate.profile.skills,
        "derived_metrics": candidate.derived_metrics,
    }
