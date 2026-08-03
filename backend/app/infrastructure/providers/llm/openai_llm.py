from __future__ import annotations

from app.core.config import LLMSettings


class OpenAICompatLLM:
    """OpenAI / DeepSeek / Qwen / Llama (vLLM, Ollama) — any OpenAI-compatible chat endpoint."""

    def __init__(self, settings: LLMSettings) -> None:
        self._settings = settings

    async def complete(
        self,
        system: str,
        user: str,
        *,
        json_mode: bool = False,
        temperature: float = 0.0,
        max_tokens: int = 4096,
    ) -> str:
        try:
            from openai import AsyncOpenAI
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("openai SDK not installed") from exc

        client = AsyncOpenAI(
            api_key="not-needed",
            base_url=self._settings.base_url,
            timeout=self._settings.timeout_s,
            max_retries=self._settings.max_retries,
        )
        kwargs: dict = {
            "model": self._settings.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if json_mode and self._settings.json_mode:
            kwargs["response_format"] = {"type": "json_object"}

        resp = await client.chat.completions.create(**kwargs)
        return resp.choices[0].message.content or ""

    async def __aenter__(self) -> "OpenAICompatLLM":
        return self

    async def __aexit__(self, *exc) -> None:  # type: ignore[no-untyped-def]
        return None
