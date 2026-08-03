from __future__ import annotations

from fastapi import APIRouter, Depends

from app.core.container import Container

router = APIRouter(tags=["health"])


def get_container() -> Container:
    return Container()


@router.get("/healthz")
async def liveness() -> dict:
    return {"status": "ok"}


@router.get("/readyz")
async def readiness() -> dict:
    c = get_container()
    try:
        await c.vector_store.ensure_collection()
        return {"status": "ok", "deps": {"vector": "ok"}}
    except Exception as exc:  # pragma: no cover
        return {"status": "degraded", "deps": {"vector": str(exc)}}
