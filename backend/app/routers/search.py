from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from app.di.injection import (
    reindex_embeddings_use_case,
    semantic_search_use_case,
    unified_search_use_case,
)
from app.rag import EmbeddingError, VectorStoreError

router = APIRouter(prefix="/search", tags=["search"])


class SemanticSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    entity: Literal["job", "candidate"] = "candidate"
    top_k: int = Field(10, ge=1, le=50)
    job_id: str | None = None


class ReindexRequest(BaseModel):
    job_id: str | None = None


@router.post("/semantic")
async def semantic_search(payload: SemanticSearchRequest) -> dict:
    """Semantic search over jobs or candidates using local embeddings + Qdrant.
    Returns `enabled: false` when RAG is not configured (opt-in)."""
    try:
        return await semantic_search_use_case().execute(
            query=payload.query,
            entity=payload.entity,
            top_k=payload.top_k,
            job_id=payload.job_id,
        )
    except (EmbeddingError, VectorStoreError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("")
async def unified_search(
    keyword: str = Query(..., min_length=1, max_length=200),
    limit: int = Query(5, ge=1, le=50),
) -> dict:
    """Unified search over jobs and candidates, returns top results for both."""
    return await unified_search_use_case().execute(keyword=keyword, limit=limit)


@router.post("/reindex")
async def reindex(
    payload: ReindexRequest | None = None,
    job_id: str | None = Query(None, description="Reindex a single job (plus its CVs)."),
) -> dict:
    """Build/rebuild the vector index. Backfills all jobs + candidates by default,
    or a single job when `job_id` is given. No-op when RAG is disabled."""
    target = (payload.job_id if payload else None) or job_id
    try:
        return await reindex_embeddings_use_case().execute(job_id=target)
    except (EmbeddingError, VectorStoreError) as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
