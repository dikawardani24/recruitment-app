from __future__ import annotations

from uuid import UUID, uuid4

from app.core.config import EmbeddingSettings, VectorSettings
from app.core.ports import EmbeddingProvider
from app.domain.entities import SemanticChunk, VectorHit

try:
    from qdrant_client import AsyncQdrantClient
    from qdrant_client.models import (
        Distance,
        FieldCondition,
        Filter,
        FilterSelector,
        MatchAny,
        MatchValue,
        PointStruct,
        VectorParams,
    )
except ImportError:  # pragma: no cover
    AsyncQdrantClient = None  # type: ignore[assignment]


class QdrantVectorStore:
    """Qdrant adapter implementing the VectorStore port.

    Points carry metadata (candidate_id, section, chunk_id, original text...).
    Collection is version-gated by embedding model+version (doc 02 §4/§6).
    """

    def __init__(self, settings: VectorSettings, embedding_provider: EmbeddingProvider) -> None:
        self._settings = settings
        self._embedding = embedding_provider
        self._client: AsyncQdrantClient | None = None

    @property
    def _collection(self) -> str:
        return f"{self._settings.collection_prefix}resume_chunks"

    async def _get_client(self) -> "AsyncQdrantClient":  # type: ignore[no-untyped-def]
        if self._client is None:
            if AsyncQdrantClient is None:  # pragma: no cover
                raise RuntimeError("qdrant-client not installed")
            self._client = AsyncQdrantClient(url=self._settings.url)
            await self.ensure_collection()
        return self._client

    async def ensure_collection(self) -> None:
        client = self._client
        if client is None:
            return
        if not await client.collection_exists(self._collection):
            await client.create_collection(
                collection_name=self._collection,
                vectors_config=VectorParams(size=self._embedding.dimension, distance=Distance.COSINE),
            )

    async def upsert(self, chunks: list[SemanticChunk], model: str, version: int) -> None:
        client = await self._get_client()
        texts = [c.text for c in chunks]
        vectors = await self._embedding.embed(texts)

        points = [
            PointStruct(
                id=str(c.id),
                vector=vec,
                payload={
                    "candidate_id": str(c.candidate_id),
                    "candidate_name": c.candidate_name,
                    "resume_id": str(c.resume_id),
                    "section": c.section.value,
                    "chunk_id": str(c.id),
                    "original_text": c.text,
                    "embedding_model": model,
                    "version": version,
                },
            )
            for c, vec in zip(chunks, vectors)
        ]
        await client.upsert(collection_name=self._collection, points=points)

    async def search(
        self,
        query_embedding: list[float],
        *,
        filters: dict | None = None,
        top_k: int = 50,
    ) -> list[VectorHit]:
        client = await self._get_client()
        qfilter = None
        if filters:
            conditions = []
            for key, value in filters.items():
                if isinstance(value, list):
                    conditions.append(FieldCondition(key=f"payload.{key}", match=MatchAny(any=value)))
                else:
                    conditions.append(FieldCondition(key=f"payload.{key}", match=MatchValue(value=value)))
            qfilter = Filter(must=conditions)

        results = await client.search(
            collection_name=self._collection,
            query_vector=query_embedding,
            limit=top_k,
            query_filter=qfilter,
            with_payload=True,
        )
        out: list[VectorHit] = []
        for r in results:
            p = r.payload or {}
            out.append(
                VectorHit(
                    chunk_id=UUID(p.get("chunk_id", str(uuid4()))),
                    candidate_id=UUID(p["candidate_id"]),
                    candidate_name=p.get("candidate_name", ""),
                    resume_id=UUID(p["resume_id"]),
                    section=p.get("section", "skills"),
                    text=p.get("original_text", ""),
                    score=float(r.score),
                )
            )
        return out

    async def delete_by_candidate(self, candidate_id: UUID, version: int | None = None) -> None:
        client = await self._get_client()
        cond = FieldCondition(key="payload.candidate_id", match=MatchValue(value=str(candidate_id)))
        await client.delete(
            collection_name=self._collection,
            points_selector=FilterSelector(filter=Filter(must=[cond])),
        )

    async def delete_by_resume(self, resume_id: UUID, version: int | None = None) -> None:
        client = await self._get_client()
        cond = FieldCondition(key="payload.resume_id", match=MatchValue(value=str(resume_id)))
        await client.delete(
            collection_name=self._collection,
            points_selector=FilterSelector(filter=Filter(must=[cond])),
        )
