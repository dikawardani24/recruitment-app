from __future__ import annotations

from app.core.config import EmbeddingSettings
from app.core.ports import EmbeddingProvider


class GeminiEmbedding(EmbeddingProvider):
    """Google Gemini text-embedding adapter."""

    def __init__(self, settings: EmbeddingSettings) -> None:
        self._settings = settings

    @property
    def model_name(self) -> str:
        return self._settings.model

    @property
    def dimension(self) -> int:
        return self._settings.dimension

    async def embed(self, texts: list[str]) -> list[list[float]]:
        from google import genai

        client = genai.Client()
        result = client.models.embed_content(model=self._settings.model, contents=texts)
        return [emb.values for emb in result.embeddings]

    def embed_query(self, query: str) -> list[float]:
        import asyncio

        return asyncio.run(self.embed([query]))[0]
