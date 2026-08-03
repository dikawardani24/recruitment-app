from functools import lru_cache
from pathlib import Path
from typing import Literal, Optional

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class DBSettings(BaseSettings):
    url: str = "postgresql+asyncpg://ats:ats@localhost:5432/ats"
    pool_size: int = 10
    max_overflow: int = 20


class RedisSettings(BaseSettings):
    url: str = "redis://localhost:6379/0"


class VectorSettings(BaseSettings):
    provider: Literal["qdrant", "pgvector"] = "qdrant"
    url: str = "http://localhost:6333"
    collection_prefix: str = "ats_"
    distance: Literal["cosine", "dot"] = "cosine"


class StorageSettings(BaseSettings):
    provider: Literal["local", "s3"] = "local"
    bucket: str = "ats-resumes"
    region: str = "us-east-1"
    local_root: Path = Path("./data/resumes")


class EmbeddingSettings(BaseSettings):
    provider: Literal["bge-small-en-v1.5", "openai", "gemini", "debug"] = "bge-small-en-v1.5"
    model: str = "BAAI/bge-small-en-v1.5"
    dimension: int = 384
    batch_size: int = 32
    normalize: bool = True
    query_instruction: str = "Represent this sentence for searching relevant passages:"


class LLMSettings(BaseSettings):
    provider: Literal["openai", "gemini", "ollama", "vllm", "deepseek"] = "openai"
    model: str = "gpt-4o-mini"
    base_url: Optional[str] = None
    temperature: float = 0.0
    json_mode: bool = True
    timeout_s: float = 30.0
    max_retries: int = 2


class OCRSettings(BaseSettings):
    provider: Literal["tesseract", "paddle"] = "tesseract"
    lang: str = "eng"
    dpi: int = 300


class SearchSettings(BaseSettings):
    top_k: int = 50
    candidate_count: int = 20
    min_score: float = 0.3
    llm_timeout_ms: int = 4000
    hybrid: bool = False


class RankingWeights(BaseSettings):
    skill: float = 0.40
    experience: float = 0.30
    education: float = 0.15
    certification: float = 0.10
    hidden_gem: float = 0.05
    llm_delta_cap: float = 0.08
    bucket_best: float = 0.80
    bucket_strong: float = 0.60
    bucket_hidden_gem: float = 0.45
    bucket_hidden_gem_high: float = 0.74
    hidden_gem_min_score: float = 0.5


class PipelineSettings(BaseSettings):
    max_retries: int = 3
    max_file_size_mb: int = 10
    min_text_density: int = 200
    concurrency: int = 4
    dlq: bool = True


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="ATS_",
        env_nested_delimiter="__",
        extra="ignore",
    )

    app_name: str = "ai-ats"
    debug: bool = False
    api_v1_prefix: str = "/v1"
    jwt_secret: str = Field(default="change-me", repr=False)
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 7

    db: DBSettings = DBSettings()
    redis: RedisSettings = RedisSettings()
    vector: VectorSettings = VectorSettings()
    storage: StorageSettings = StorageSettings()
    embedding: EmbeddingSettings = EmbeddingSettings()
    llm: LLMSettings = LLMSettings()
    ocr: OCRSettings = OCRSettings()
    search: SearchSettings = SearchSettings()
    ranking: RankingWeights = RankingWeights()
    pipeline: PipelineSettings = PipelineSettings()


@lru_cache
def get_settings() -> Settings:
    return Settings()
