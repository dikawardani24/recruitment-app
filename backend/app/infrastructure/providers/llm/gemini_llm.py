from __future__ import annotations

from app.core.config import LLMSettings
from app.core.ports import LLMProvider


class GeminiLLM(LLMProvider):
    """Google Gemini chat-completions adapter."""

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
        from google import genai

        client = genai.Client()
        config = {"system_instruction": system, "temperature": temperature, "max_output_tokens": max_tokens}
        if json_mode:
            config["response_mime_type"] = "application/json"

        resp = client.models.generate_content(
            model=self._settings.model,
            contents=user,
            config=config,
        )
        return resp.text or ""
