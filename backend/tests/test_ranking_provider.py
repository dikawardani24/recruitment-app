from app.config import Settings


def test_ranking_prefers_the_default_llm_provider():
    settings = Settings()
    settings.llm_api_key = "gemini-key"
    settings.llm_base_url = "https://gemini.example/v1"
    settings.llm_model = "gemini-model"
    settings.openrouter_api_key = "openrouter-key"
    settings.openrouter_base_url = "https://openrouter.ai/api/v1"
    settings.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    assert settings.ranking_llm_api_key == "gemini-key"
    assert settings.ranking_llm_base_url == "https://gemini.example/v1"
    assert settings.ranking_llm_model == "gemini-model"


def test_ranking_uses_openrouter_when_the_default_llm_has_no_key():
    settings = Settings()
    settings.llm_api_key = None
    settings.openrouter_api_key = "openrouter-key"
    settings.openrouter_base_url = "https://openrouter.ai/api/v1"
    settings.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    assert settings.ranking_llm_enabled is True
    assert settings.ranking_llm_api_key == "openrouter-key"
    assert settings.ranking_llm_base_url == "https://openrouter.ai/api/v1"
    assert settings.ranking_llm_model == "qwen/qwen-2.5-72b-instruct"


def test_ranking_uses_rules_when_neither_provider_has_a_key():
    settings = Settings()
    settings.llm_api_key = None
    settings.openrouter_api_key = None

    assert settings.ranking_llm_enabled is False
