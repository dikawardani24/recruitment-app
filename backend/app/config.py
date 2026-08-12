from __future__ import annotations

from dotenv import load_dotenv

load_dotenv()

import os
from dataclasses import dataclass, field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class ChatModelOption:
    """A chat-completion model a recruiter can pick from.

    ``id`` is the stable identifier used in the API and the chat UI.
    ``model`` is the model name sent to the provider's OpenAI-compatible
    endpoint at ``base_url`` using ``api_key``.
    """

    id: str
    label: str
    provider: str
    base_url: str
    api_key: str | None
    model: str

    def with_api_key(self, api_key: str | None) -> "ChatModelOption":
        """Return a copy of this option with [api_key] overriding the configured one."""
        if api_key is None:
            return self
        return ChatModelOption(
            id=self.id,
            label=self.label,
            provider=self.provider,
            base_url=self.base_url,
            api_key=api_key,
            model=self.model,
        )


def _list_env(name: str, default: str = "") -> list[str]:
    raw = os.getenv(name, default)
    return [part.strip() for part in raw.split(",") if part.strip()]


@dataclass
class Settings:
    app_name: str = os.getenv("ATS_APP_NAME", "ai-ats")
    debug: bool = os.getenv("ATS_DEBUG", "false").lower() in ("1", "true", "yes")

    db_path: Path = field(
        default_factory=lambda: Path(
            os.getenv("ATS_DB__PATH", str(BASE_DIR / "data" / "ats.db"))
        )
    )
    upload_dir: Path = field(
        default_factory=lambda: Path(
            os.getenv("ATS_UPLOAD_DIR", str(BASE_DIR / "data" / "uploads"))
        )
    )

    # CV import / background processing.
    import_batch_size: int = int(os.getenv("ATS_IMPORT__BATCH_SIZE", "20"))
    import_worker_concurrency: int = int(os.getenv("ATS_IMPORT__WORKERS", "4"))
    import_poll_interval_ms: int = int(os.getenv("ATS_IMPORT__POLL_MS", "1000"))
    import_retry_delay_ms: int = int(os.getenv("ATS_IMPORT__RETRY_DELAY_MS", "200"))

    # LLM (optional). When unset, ranking falls back to deterministic rule-based
    # scoring + template reasoning. Supports OpenAI and OpenAI-compatible endpoints
    # (e.g. Google Gemini at https://generativelanguage.googleapis.com/v1beta/openai/).
    llm_api_key: str | None = os.getenv("ATS_LLM__API_KEY") or os.getenv("GEMINI_API_KEY") or os.getenv("OPENAI_API_KEY")
    llm_base_url: str | None = os.getenv("ATS_LLM__BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai/")
    llm_model: str = os.getenv("ATS_LLM__MODEL", "gemini-flash-latest")
    llm_timeout_ms: int = int(os.getenv("ATS_LLM__TIMEOUT_MS", "20000"))
    # Provider throttling: hard per-minute request cap and bounded retries.
    llm_max_retries: int = int(os.getenv("ATS_LLM__MAX_RETRIES", "3"))
    llm_retry_base_ms: int = int(os.getenv("ATS_LLM__RETRY_BASE_MS", "1500"))
    llm_min_interval_ms: int = int(os.getenv("ATS_LLM__MIN_INTERVAL_MS", "12000"))

    # Recruiter-copilot chat (optional). Reuses the LLM key/base URL above, but
    # can point at its own model. The chatbot uses a dedicated recruitment-scoped
    # system prompt and grounds answers in RAG evidence (docs/10 §6).
    chat_model: str = os.getenv("ATS_CHAT__MODEL", "") or os.getenv("ATS_LLM__MODEL", "gemini-flash-latest")
    chat_temperature: float = float(os.getenv("ATS_CHAT__TEMPERATURE", "0.3"))
    chat_max_tokens: int = int(os.getenv("ATS_CHAT__MAX_TOKENS", "800"))
    chat_history_turns: int = int(os.getenv("ATS_CHAT__HISTORY_TURNS", "6"))

    # OpenRouter (optional) — an OpenAI-compatible router hosting many models
    # (e.g. Qwen). When ATS_OPENROUTER__API_KEY is set, every model in
    # ATS_OPENROUTER__MODELS becomes selectable in the recruiter-copilot chat.
    openrouter_api_key: str | None = os.getenv("ATS_OPENROUTER__API_KEY") or os.getenv("OPENROUTER_API_KEY")
    openrouter_base_url: str = os.getenv(
        "ATS_OPENROUTER__BASE_URL", "https://openrouter.ai/api/v1"
    )
    openrouter_models: list[str] = field(
        default_factory=lambda: _list_env(
            "ATS_OPENROUTER__MODELS", "qwen/qwen-2.5-72b-instruct"
        )
    )

    # Local BERT resume-NER (optional; overrides LLM extraction when enabled).
    ner_enabled: bool = os.getenv("ATS_EXTRACT__NER", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    ner_model: str = os.getenv("ATS_EXTRACT__NER_MODEL", "yashpwr/resume-ner-bert")
    ner_confidence: float = float(os.getenv("ATS_EXTRACT__NER_CONFIDENCE", "0.5"))

    # Ranking weights (must sum to 1.0).
    w_skill: float = float(os.getenv("ATS_RANKING__SKILL", "0.40"))
    w_experience: float = float(os.getenv("ATS_RANKING__EXPERIENCE", "0.30"))
    w_education: float = float(os.getenv("ATS_RANKING__EDUCATION", "0.15"))
    w_certification: float = float(os.getenv("ATS_RANKING__CERTIFICATION", "0.15"))

    # RAG (optional, opt-in). When disabled, semantic search reports itself as
    # disabled and no vectors are written. Embeddings run locally with a free
    # open-source model (torch/transformers are already dependencies for NER).
    rag_enabled: bool = os.getenv("ATS_RAG__ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    rag_embedding_model: str = os.getenv(
        "ATS_RAG__EMBEDDING_MODEL", "BAAI/bge-small-en-v1.5"
    )
    rag_embedding_dim: int = int(os.getenv("ATS_RAG__EMBEDDING_DIM", "384"))
    rag_embedding_version: str = os.getenv(
        "ATS_RAG__EMBEDDING_VERSION", "bge-small-en-v1.5:v1"
    )
    rag_top_k: int = int(os.getenv("ATS_RAG__TOP_K", "20"))

    # Qdrant vector store. Defaults to Qdrant's embedded/local mode (persistent
    # files, no server). Set ATS_QDRANT__URL to point at a running Qdrant server.
    qdrant_path: Path = field(
        default_factory=lambda: Path(
            os.getenv("ATS_QDRANT__PATH", str(BASE_DIR / "data" / "qdrant"))
        )
    )
    qdrant_url: str | None = os.getenv("ATS_QDRANT__URL")
    qdrant_collection: str = os.getenv("ATS_QDRANT__COLLECTION", "recruitment")

    def ensure_dirs(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        if self.rag_enabled:
            self.qdrant_path.mkdir(parents=True, exist_ok=True)

    @property
    def llm_enabled(self) -> bool:
        return bool(self.llm_api_key)

    @property
    def chat_enabled(self) -> bool:
        return bool(self.llm_api_key or self.openrouter_api_key)

    def chat_enabled_with_key(self, runtime_key: str | None = None) -> bool:
        """Return True if chat can be used.

        Falls back to a per-request [runtime_key] (e.g. supplied by the client)
        when no server-side key is configured at startup.
        """
        return bool(self.llm_api_key or self.openrouter_api_key or runtime_key)

    @property
    def chat_models(self) -> list[ChatModelOption]:
        """Every model the recruiter-copilot chat can use, in display order.

        The default endpoint model (Gemini by default) always comes first, then
        each OpenRouter model. Only providers with an API key are included.
        """
        options: list[ChatModelOption] = []
        if self.llm_api_key:
            options.append(
                ChatModelOption(
                    id="default",
                    label=self.chat_model,
                    provider="default",
                    base_url=self.llm_base_url or "",
                    api_key=self.llm_api_key,
                    model=self.chat_model,
                )
            )
        if self.openrouter_api_key:
            for model in self.openrouter_models:
                options.append(
                    ChatModelOption(
                        id=f"openrouter:{model}",
                        label=f"Qwen via OpenRouter ({model})",
                        provider="openrouter",
                        base_url=self.openrouter_base_url,
                        api_key=self.openrouter_api_key,
                        model=model,
                    )
                )
        return options

    def resolve_chat_model(self, model_id: str | None) -> ChatModelOption | None:
        """Return the [ChatModelOption] for ``model_id``, or None if no provider
        is configured.

        A missing or unknown ``model_id`` falls back to the first available
        option (the default provider's model) when any provider is configured.
        """
        options = self.chat_models
        if not options:
            return None
        if not model_id:
            return options[0]
        for option in options:
            if option.id == model_id:
                return option
        return options[0]


settings = Settings()
