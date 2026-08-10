from __future__ import annotations

from app.config import Settings


class ChatError(Exception):
    pass


class ChatClient:
    """OpenAI-compatible chat completions for the recruiter copilot. Reuses the
    LLM key/base URL; only the model is overridable via ATS_CHAT__MODEL."""

    def __init__(self, settings: Settings):
        self.settings = settings

    async def complete(self, system: str, user: str) -> str:
        if not self.settings.chat_enabled:
            raise ChatError("chat_not_configured")

        import openai

        kwargs: dict = {
            "api_key": self.settings.llm_api_key,
            "timeout": self.settings.llm_timeout_ms / 1000.0,
        }
        if self.settings.llm_base_url:
            kwargs["base_url"] = self.settings.llm_base_url
        client = openai.AsyncOpenAI(**kwargs)

        try:
            response = await client.chat.completions.create(
                model=self.settings.chat_model,
                temperature=self.settings.chat_temperature,
                max_tokens=self.settings.chat_max_tokens,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
            )
        except Exception as exc:  # network, auth, quota, etc.
            raise ChatError(f"chat_call_failed:{type(exc).__name__}") from exc

        return (response.choices[0].message.content or "").strip()
