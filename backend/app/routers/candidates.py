from __future__ import annotations

from fastapi import APIRouter, Query

from app.di.injection import search_candidates_use_case

router = APIRouter(prefix="/candidates", tags=["candidates"])


@router.get("/search")
async def search_candidates(
    keyword: str = Query(..., max_length=200),
    page: int = Query(1, ge=1),
    limit: int = Query(20, alias="limit", ge=1, le=100),
) -> dict:
    """Search candidates by name, skills, or file name across all jobs."""
    return await search_candidates_use_case().execute(
        keyword=keyword, page=page, page_size=limit
    )
