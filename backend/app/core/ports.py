from __future__ import annotations

from typing import Protocol, runtime_checkable
from uuid import UUID

from app.domain.entities import Candidate, CandidateRanking, Resume, SemanticChunk, VectorHit


@runtime_checkable
class EmbeddingProvider(Protocol):
    @property
    def model_name(self) -> str: ...

    @property
    def dimension(self) -> int: ...

    async def embed(self, texts: list[str]) -> list[list[float]]: ...

    def embed_query(self, query: str) -> list[float]: ...


@runtime_checkable
class LLMProvider(Protocol):
    async def complete(
        self,
        system: str,
        user: str,
        *,
        json_mode: bool = False,
        temperature: float = 0.0,
        max_tokens: int = 4096,
    ) -> str: ...


@runtime_checkable
class VectorStore(Protocol):
    async def ensure_collection(self) -> None: ...

    async def upsert(self, chunks: list[SemanticChunk], model: str, version: int) -> None: ...

    async def search(
        self,
        query_embedding: list[float],
        *,
        filters: dict | None = None,
        top_k: int = 50,
    ) -> list[VectorHit]: ...

    async def delete_by_candidate(self, candidate_id: UUID, version: int | None = None) -> None: ...

    async def delete_by_resume(self, resume_id: UUID, version: int | None = None) -> None: ...


@runtime_checkable
class OCRProvider(Protocol):
    async def extract(self, image_bytes: bytes, lang: str = "eng") -> str: ...


@runtime_checkable
class ObjectStorage(Protocol):
    async def put(self, key: str, data: bytes, content_type: str) -> None: ...

    async def get(self, key: str) -> bytes: ...

    async def delete(self, key: str) -> None: ...


@runtime_checkable
class FileParser(Protocol):
    async def extract_text(self, data: bytes) -> tuple[str, dict]: ...


@runtime_checkable
class CandidateRepository(Protocol):
    async def get(self, candidate_id: UUID) -> Candidate | None: ...

    async def get_many(self, candidate_ids: list[UUID]) -> list[Candidate]: ...

    async def save(self, candidate: Candidate) -> Candidate: ...

    async def delete(self, candidate_id: UUID) -> None: ...


@runtime_checkable
class ResumeRepository(Protocol):
    async def get(self, resume_id: UUID) -> Resume | None: ...

    async def save(self, resume: Resume) -> Resume: ...

    async def create(self, resume: Resume) -> Resume: ...

    async def get_by_candidate(self, candidate_id: UUID) -> list[Resume]: ...

    async def get_by_hash(self, sha256: str) -> Resume | None: ...


@runtime_checkable
class RankingRepository(Protocol):
    async def save(self, ranking: CandidateRanking) -> None: ...

    async def list_by_job(self, job_id: UUID) -> list[CandidateRanking]: ...
