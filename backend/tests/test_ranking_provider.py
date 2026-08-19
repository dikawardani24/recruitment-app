from app.config import Settings


def test_ranking_prefers_the_default_llm_provider():
    settings = Settings()
    settings.llm_api_key = "gemini-key"
    settings.llm_base_url = "https://gemini.example/v1"
    settings.llm_model = "gemini-model"
    settings.openrouter_api_key = "openrouter-key"
    settings.openrouter_base_url = "https://openrouter.ai/api/v1"
    settings.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    assert settings.ranking_llm_api_key() == "gemini-key"
    assert settings.ranking_llm_base_url() == "https://gemini.example/v1"
    assert settings.ranking_llm_model() == "gemini-model"


def test_ranking_uses_openrouter_when_the_default_llm_has_no_key():
    settings = Settings()
    settings.llm_api_key = None
    settings.openrouter_api_key = "openrouter-key"
    settings.openrouter_base_url = "https://openrouter.ai/api/v1"
    settings.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    assert settings.ranking_llm_enabled() is True
    assert settings.ranking_llm_api_key() == "openrouter-key"
    assert settings.ranking_llm_base_url() == "https://openrouter.ai/api/v1"
    assert settings.ranking_llm_model() == "qwen/qwen-2.5-72b-instruct"


def test_ranking_uses_rules_when_neither_provider_has_a_key():
    settings = Settings()
    settings.llm_api_key = None
    settings.openrouter_api_key = None

    assert settings.ranking_llm_enabled() is False


def test_ranking_runtime_key_override():
    settings = Settings()
    settings.llm_api_key = "server-gemini-key"
    settings.llm_base_url = "https://gemini.example/v1"
    settings.llm_model = "gemini-model"
    settings.openrouter_api_key = "server-openrouter-key"
    settings.openrouter_base_url = "https://openrouter.ai/api/v1"
    settings.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    # Runtime key override (OpenRouter)
    runtime_key = "sk-or-runtime-key"
    attempts = settings.ranking_attempts(runtime_key)
    assert len(attempts) == 1
    assert attempts[0]["api_key"] == "sk-or-runtime-key"
    assert attempts[0]["base_url"] == "https://openrouter.ai/api/v1"
    assert attempts[0]["model"] == "qwen/qwen-2.5-72b-instruct"

    # Server-side attempts (no runtime key)
    attempts = settings.ranking_attempts()
    assert len(attempts) == 2
    assert attempts[0]["provider"] == "default"
    assert attempts[0]["api_key"] == "server-gemini-key"
    assert attempts[1]["provider"] == "openrouter"
    assert attempts[1]["api_key"] == "server-openrouter-key"
