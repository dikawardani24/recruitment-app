from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


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

    # LLM (optional). When unset, ranking falls back to deterministic rule-based
    # scoring + template reasoning. Supports OpenAI and OpenAI-compatible endpoints
    # (e.g. Google Gemini at https://generativelanguage.googleapis.com/v1beta/openai/).
    llm_api_key: str | None = os.getenv("ATS_LLM__API_KEY") or os.getenv("GEMINI_API_KEY") or os.getenv("OPENAI_API_KEY")
    llm_base_url: str | None = os.getenv("ATS_LLM__BASE_URL", "https://generativelanguage.googleapis.com/v1beta/openai/")
    llm_model: str = os.getenv("ATS_LLM__MODEL", "gemini-1.5-flash")
    llm_timeout_ms: int = int(os.getenv("ATS_LLM__TIMEOUT_MS", "20000"))

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

    def ensure_dirs(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.upload_dir.mkdir(parents=True, exist_ok=True)

    @property
    def llm_enabled(self) -> bool:
        return bool(self.llm_api_key)


settings = Settings()
