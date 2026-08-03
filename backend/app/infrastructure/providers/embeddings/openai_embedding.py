from __future__ import annotations

from app.core.config import EmbeddingSettings
from app.core.ports import EmbeddingProvider


class OpenAIEmbedding(EmbeddingProvider):
    """OpenAI text-embedding adapter (text-embedding-3-small)."""

    def __init__(self, settings: EmbeddingSettings) -> None:
        self._settings = settings

    @property
    def model_name(self) -> str:
        return self._settings.model

    @property
    def dimension(self) -> int:
        return self._settings.dimension

    async def embed(self, texts: list[str]) -> list[list[float]]:
        from openai import AsyncOpenAI

        client = AsyncOpenAI()
        resp = await client.embeddings.create(model=self._settings.model, input=texts)
        return [d.embedding for d in resp.data]

    def embed_query(self, query: str) -> list[float]:
        import asyncio

        return asyncio.run(self.embed([query]))[0]
