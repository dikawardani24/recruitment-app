from __future__ import annotations

import numpy as np

from app.core.config import EmbeddingSettings

try:
    from sentence_transformers import SentenceTransformer

    _HAS_ST = True
except ImportError:  # pragma: no cover
    _HAS_ST = False


class LocalBGEEmbedding:
    """BAAI/bge-small-en-v1.5 via sentence-transformers (CPU-friendly, 384-dim)."""

    def __init__(self, settings: EmbeddingSettings) -> None:
        self._settings = settings
        self._model = None

    @property
    def model_name(self) -> str:
        return self._settings.model

    @property
    def dimension(self) -> int:
        return self._settings.dimension

    def _load(self) -> None:  # pragma: no cover - requires model download
        if self._model is None:
            if not _HAS_ST:
                raise RuntimeError("sentence-transformers not installed")
            self._model = SentenceTransformer(self._settings.model)

    async def embed(self, texts: list[str]) -> list[list[float]]:
        self._load()
        vectors = self._model.encode(
            texts,
            batch_size=self._settings.batch_size,
            normalize_embeddings=self._settings.normalize,
        )
        return [v.tolist() for v in vectors]

    def embed_query(self, query: str) -> list[float]:
        self._load()
        prefixed = f"{self._settings.query_instruction} {query}"
        v = self._model.encode(
            prefixed,
            normalize_embeddings=self._settings.normalize,
        )
        return np.asarray(v, dtype=np.float32).tolist()
