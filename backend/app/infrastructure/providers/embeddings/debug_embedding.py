from __future__ import annotations

import hashlib

from app.core.config import EmbeddingSettings
from app.core.ports import EmbeddingProvider


class DebugEmbedding(EmbeddingProvider):
    """Deterministic hash embedding for local development and tests.

    NOT semantically meaningful — used only to exercise the full pipeline
    without downloading a model. Selected via `provider=debug`.
    """

    def __init__(self, settings: EmbeddingSettings) -> None:
        self._settings = settings

    @property
    def model_name(self) -> str:
        return "debug-hash"

    @property
    def dimension(self) -> int:
        return self._settings.dimension

    def _vector(self, text: str) -> list[float]:
        digest = hashlib.sha256(text.encode()).digest()
        dim = self._settings.dimension
        vec = [0.0] * dim
        for i, byte in enumerate(digest):
            vec[i % dim] += byte / 255.0
        norm = sum(v * v for v in vec) ** 0.5 or 1.0
        return [v / norm for v in vec]

    async def embed(self, texts: list[str]) -> list[list[float]]:
        return [self._vector(t) for t in texts]

    def embed_query(self, query: str) -> list[float]:
        return self._vector(query)
