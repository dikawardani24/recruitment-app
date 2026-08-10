from __future__ import annotations

from typing import Protocol
from uuid import NAMESPACE_DNS, uuid5

from app.config import Settings
from app.domain.candidate import Candidate
from app.domain.job import Job
from app.rag._chunker import chunk_candidate, chunk_job
from app.rag._embedder import QUERY_PREFIX, Embedder
from app.rag._qdrant import Point, ScoredHit

_ID_NAMESPACE = NAMESPACE_DNS


class VectorStoreProtocol(Protocol):
    async def upsert(self, points: list[Point]) -> None: ...

    async def delete(self, must: list[tuple[str, object]]) -> None: ...

    async def count(self, must: list[tuple[str, object]]) -> int: ...

    async def search(self, vector: list[float], must: list[tuple[str, object]], limit: int) -> list[ScoredHit]: ...

    def close(self) -> None: ...


class EmbeddingIndexer:
    """Write/query path for RAG. Indexing is idempotent: re-indexing an entity
    deletes its existing points (any version) and upserts fresh ones tagged with
    the active embedding version. Search always filters on the active version."""

    def __init__(
        self,
        settings: Settings,
        embedder: Embedder,
        store: VectorStoreProtocol,
    ):
        self.settings = settings
        self.embedder = embedder
        self.store = store

    @property
    def enabled(self) -> bool:
        return self.settings.rag_enabled

    @property
    def model(self) -> str:
        return self.settings.rag_embedding_model

    @property
    def version(self) -> str:
        return self.settings.rag_embedding_version

    async def index_candidate(self, candidate: Candidate) -> int:
        chunks = chunk_candidate(candidate)
        return await self._index(
            entity_type="candidate",
            entity_id=candidate.id,
            job_id=candidate.job_id,
            entity_name=candidate.candidate_name or "",
            chunks=[(c.section, c.content) for c in chunks],
        )

    async def index_job(self, job: Job) -> int:
        chunks = chunk_job(job)
        return await self._index(
            entity_type="job",
            entity_id=job.id,
            job_id=None,
            entity_name=job.title,
            chunks=[(c.section, c.content) for c in chunks],
        )

    async def _index(
        self,
        *,
        entity_type: str,
        entity_id: str,
        job_id: str | None,
        entity_name: str,
        chunks: list[tuple[str, str]],
    ) -> int:
        contents = [content for _, content in chunks]
        vectors = await self.embedder.embed(contents)

        points = []
        for index, ((section, content), vector) in enumerate(zip(chunks, vectors)):
            payload = {
                "entity_type": entity_type,
                "entity_id": entity_id,
                "job_id": job_id,
                "section": section,
                "content": content,
                "entity_name": entity_name,
                "embedding_model": self.model,
                "version": self.version,
            }
            points.append(
                Point(
                    id=self._point_id(entity_type, entity_id, section, index),
                    vector=vector,
                    payload=payload,
                )
            )

        await self.store.delete([("entity_type", entity_type), ("entity_id", entity_id)])
        await self.store.upsert(points)
        return len(points)

    async def delete_entity(self, entity_type: str, entity_id: str) -> None:
        await self.store.delete([("entity_type", entity_type), ("entity_id", entity_id)])

    async def delete_by_job(self, job_id: str) -> None:
        await self.store.delete([("job_id", job_id)])

    async def count_indexed(self) -> int:
        return await self.store.count([("version", self.version)])

    async def embed_query(self, query: str) -> list[float]:
        vectors = await self.embedder.embed([f"{QUERY_PREFIX}{query}"])
        return vectors[0]

    async def search(
        self,
        query: str,
        entity_type: str,
        top_k: int,
        job_id: str | None = None,
    ) -> list[ScoredHit]:
        vector = await self.embed_query(query)
        must: list[tuple[str, object]] = [
            ("entity_type", entity_type),
            ("version", self.version),
        ]
        if job_id:
            must.append(("job_id", job_id))
        return await self.store.search(vector, must, limit=top_k)

    def _point_id(self, entity_type: str, entity_id: str, section: str, index: int) -> str:
        key = f"{entity_type}:{entity_id}:{section}:{index}:{self.version}"
        return str(uuid5(_ID_NAMESPACE, key))

    def close(self) -> None:
        self.store.close()
