from __future__ import annotations

import asyncio
import threading
from typing import Protocol

import numpy as np

from app.config import Settings


class EmbeddingError(Exception):
    pass


# BGE recommends an instruction prefix on the query (never on indexed text).
QUERY_PREFIX = "Represent this sentence for searching relevant passages: "


class Embedder(Protocol):
    """Embeddings provider. Providers are model-agnostic; the vector dimension is
    carried by the settings and the Qdrant collection is created to match."""

    async def embed(self, texts: list[str]) -> list[list[float]]:
        ...


class LocalEmbedder:
    """Free, offline embeddings via a local transformer model (bge-small by
    default). Lazily loads the model once (mirroring the resume-NER pattern) and
    pushes blocking inference to a thread so the event loop stays responsive."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self._tokenizer = None
        self._model = None
        self._load_lock = threading.Lock()

    def _load(self) -> None:
        with self._load_lock:
            if self._model is not None:
                return
            try:
                from transformers import AutoModel, AutoTokenizer
            except ImportError as exc:  # torch/transformers not installed
                raise EmbeddingError("ml_deps_missing") from exc

            try:
                self._tokenizer = AutoTokenizer.from_pretrained(self.settings.rag_embedding_model)
                self._model = AutoModel.from_pretrained(self.settings.rag_embedding_model)
                self._model.eval()
            except Exception as exc:
                raise EmbeddingError(f"embed_model_load_failed:{type(exc).__name__}") from exc

    async def embed(self, texts: list[str]) -> list[list[float]]:
        if not texts:
            return []
        return await asyncio.to_thread(self._embed_sync, texts)

    def _embed_sync(self, texts: list[str]) -> list[list[float]]:
        import torch

        self._load()
        tokenizer = self._tokenizer
        model = self._model
        assert tokenizer is not None and model is not None

        encoded = tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=512,
            return_tensors="pt",
        )
        with torch.no_grad():
            outputs = model(**encoded)

        # Mean pooling over non-padded tokens, then L2 normalization (per
        # sentence-transformers/bge convention).
        mask = encoded["attention_mask"].unsqueeze(-1).to(dtype=outputs.last_hidden_state.dtype)
        summed = torch.sum(outputs.last_hidden_state * mask, dim=1)
        counts = torch.clamp(mask.sum(dim=1), min=1e-9)
        embeddings = (summed / counts).cpu().numpy()
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        embeddings = embeddings / np.clip(norms, 1e-9, None)
        return embeddings.tolist()
