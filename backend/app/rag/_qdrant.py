from __future__ import annotations

import asyncio
import contextlib
from dataclasses import dataclass, field
from typing import Any

from app.config import Settings


class VectorStoreError(Exception):
    pass


@dataclass(frozen=True)
class Point:
    id: str
    vector: list[float]
    payload: dict[str, Any]


@dataclass
class ScoredHit:
    score: float
    payload: dict[str, Any]


@dataclass
class VectorStore:
    """Thin async wrapper over the sync Qdrant client. Blocking calls run in a
    thread so the event loop stays responsive. Defaults to Qdrant's embedded
    (local, persistent) mode; a server URL is used when configured."""

    settings: Settings
    client: Any = field(default=None, init=False, repr=False)

    def __post_init__(self) -> None:
        from qdrant_client import QdrantClient

        if self.settings.qdrant_url:
            self.client = QdrantClient(url=self.settings.qdrant_url)
        else:
            self.settings.qdrant_path.mkdir(parents=True, exist_ok=True)
            self.client = QdrantClient(path=str(self.settings.qdrant_path))
        self._ensure_collection()

    @property
    def collection(self) -> str:
        return self.settings.qdrant_collection

    def _ensure_collection(self) -> None:
        from qdrant_client.http import models as qm

        try:
            if not self.client.collection_exists(self.collection):
                self.client.create_collection(
                    collection_name=self.collection,
                    vectors_config=qm.VectorParams(
                        size=self.settings.rag_embedding_dim,
                        distance=qm.Distance.COSINE,
                    ),
                )
        except Exception as exc:
            raise VectorStoreError(f"qdrant_ensure_failed:{type(exc).__name__}") from exc

    async def upsert(self, points: list[Point]) -> None:
        if not points:
            return
        await asyncio.to_thread(self._upsert_sync, points)

    def _upsert_sync(self, points: list[Point]) -> None:
        from qdrant_client.http import models as qm

        self.client.upsert(
            collection_name=self.collection,
            points=[
                qm.PointStruct(
                    id=point.id,
                    vector=point.vector,
                    payload=point.payload,
                )
                for point in points
            ],
        )

    async def delete(self, must: list[tuple[str, Any]]) -> None:
        await asyncio.to_thread(self._delete_sync, must)

    def _delete_sync(self, must: list[tuple[str, Any]]) -> None:
        from qdrant_client.http import models as qm

        self.client.delete(
            collection_name=self.collection,
            points_selector=qm.FilterSelector(
                filter=self._filter(must),
            ),
        )

    async def count(self, must: list[tuple[str, Any]]) -> int:
        return await asyncio.to_thread(self._count_sync, must)

    def _count_sync(self, must: list[tuple[str, Any]]) -> int:

        result = self.client.count(
            collection_name=self.collection,
            count_filter=self._filter(must),
            exact=True,
        )
        return int(result.count or 0)

    async def search(self, vector: list[float], must: list[tuple[str, Any]], limit: int) -> list[ScoredHit]:
        return await asyncio.to_thread(self._search_sync, vector, must, limit)

    def _search_sync(self, vector: list[float], must: list[tuple[str, Any]], limit: int) -> list[ScoredHit]:
        response = self.client.query_points(
            collection_name=self.collection,
            query=vector,
            query_filter=self._filter(must),
            limit=limit,
        )
        return [
            ScoredHit(score=float(hit.score), payload=dict(hit.payload or {}))
            for hit in response.points
        ]

    def _filter(self, must: list[tuple[str, Any]]):
        from qdrant_client.http import models as qm

        if not must:
            return None
        return qm.Filter(
            must=[
                qm.FieldCondition(key=key, match=qm.MatchValue(value=value))
                for key, value in must
            ]
        )

    def close(self) -> None:
        if self.client is not None:
            with contextlib.suppress(Exception):
                self.client.close()
        self.client = None
