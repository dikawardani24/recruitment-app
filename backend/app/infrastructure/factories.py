from __future__ import annotations

from app.core.config import Settings
from app.core.ports import EmbeddingProvider, LLMProvider, OCRProvider


class EmbeddingFactory:
    @staticmethod
    def create(settings: Settings) -> EmbeddingProvider:
        provider = settings.embedding.provider
        if provider == "debug":
            from app.infrastructure.providers.embeddings.debug_embedding import DebugEmbedding

            return DebugEmbedding(settings.embedding)
        if provider == "openai":
            from app.infrastructure.providers.embeddings.openai_embedding import OpenAIEmbedding

            return OpenAIEmbedding(settings.embedding)
        if provider == "gemini":
            from app.infrastructure.providers.embeddings.gemini_embedding import GeminiEmbedding

            return GeminiEmbedding(settings.embedding)
        from app.infrastructure.providers.embeddings.local_bge import LocalBGEEmbedding

        return LocalBGEEmbedding(settings.embedding)


class LLMFactory:
    @staticmethod
    def create(settings: Settings) -> LLMProvider:
        provider = settings.llm.provider
        if provider == "gemini":
            from app.infrastructure.providers.llm.gemini_llm import GeminiLLM

            return GeminiLLM(settings.llm)
        if provider in {"ollama", "vllm", "deepseek", "openai"}:
            from app.infrastructure.providers.llm.openai_llm import OpenAICompatLLM

            return OpenAICompatLLM(settings.llm)
        raise ValueError(f"Unsupported LLM provider: {provider}")


class OCRFactory:
    @staticmethod
    def create(settings: Settings) -> OCRProvider:
        if settings.ocr.provider == "paddle":
            from app.infrastructure.providers.ocr.paddle_ocr import PaddleOCRProvider

            return PaddleOCRProvider(settings.ocr)
        from app.infrastructure.providers.ocr.tesseract_ocr import TesseractOCRProvider

        return TesseractOCRProvider(settings.ocr)


class VectorStoreFactory:
    @staticmethod
    def create(settings: Settings, embedding_provider: EmbeddingProvider):
        if settings.vector.provider == "pgvector":
            from app.infrastructure.vector.pgvector_store import PgVectorStore

            return PgVectorStore(settings.vector, embedding_provider)
        from app.infrastructure.vector.qdrant_store import QdrantVectorStore

        return QdrantVectorStore(settings.vector, embedding_provider)


class StorageFactory:
    @staticmethod
    def create(settings: Settings):
        if settings.storage.provider == "s3":
            from app.infrastructure.providers.storage.s3_storage import S3Storage

            return S3Storage(settings.storage)
        from app.infrastructure.providers.storage.local_storage import LocalStorage

        return LocalStorage(settings.storage)
