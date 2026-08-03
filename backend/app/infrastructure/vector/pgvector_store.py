from __future__ import annotations

from uuid import UUID

from app.core.config import EmbeddingSettings, VectorSettings
from app.core.ports import EmbeddingProvider
from app.domain.entities import SemanticChunk, VectorHit


class PgVectorStore:
    """pgvector adapter implementing the VectorStore port (drop-in for Qdrant).

    Uses a single `vector_chunks` table with a 384-dim `embedding` column.
    Kept as a fully swappable alternative to QdrantVectorStore (doc 05 §8).
    """

    def __init__(self, settings: VectorSettings, embedding_provider: EmbeddingProvider) -> None:
        self._settings = settings
        self._embedding = embedding_provider
        self._enabled = False  # requires pgvector + asyncpg setup at startup

    async def ensure_collection(self) -> None:
        pass

    async def upsert(self, chunks: list[SemanticChunk], model: str, version: int) -> None:
        raise NotImplementedError("pgvector adapter: enable after enabling the extension")

    async def search(
        self,
        query_embedding: list[float],
        *,
        filters: dict | None = None,
        top_k: int = 50,
    ) -> list[VectorHit]:
        raise NotImplementedError("pgvector adapter: enable after enabling the extension")

    async def delete_by_candidate(self, candidate_id: UUID, version: int | None = None) -> None:
        raise NotImplementedError("pgvector adapter: enable after enabling the extension")

    async def delete_by_resume(self, resume_id: UUID, version: int | None = None) -> None:
        raise NotImplementedError("pgvector adapter: enable after enabling the extension")
