from __future__ import annotations

import json
from dataclasses import dataclass

from app.config import ChatModelOption, Settings
from app.llm._gate import bounded_retry, rate_capped_wait


class ChatError(Exception):
    pass


@dataclass(frozen=True)
class ToolCall:
    """Yielded by [ChatClient.complete_stream] just before a tool executes so the
    caller can surface progress to the user."""

    name: str
    arguments: str


MAX_TOOL_ROUNDS = 3


class ChatClient:
    """OpenAI-compatible chat completions for the recruiter copilot. Each call
    can target any configured chat model (default provider endpoint, or OpenRouter
    via ATS_OPENROUTER__MODELS) — the base URL, API key and model name are picked
    per request from [Settings.resolve_chat_model].

    Supports optional function-calling: when [tools] and [execute_tool] are given
    the client runs the model/tool loop (up to [MAX_TOOL_ROUNDS]) so the copilot
    can look up full workspace records through the registered tools."""

    def __init__(self, settings: Settings):
        self.settings = settings

    def _resolve(self, model_id: str | None) -> ChatModelOption:
        """Resolve the requested model, raising if it is not configured."""
        option = self.settings.resolve_chat_model(model_id)
        if option is None:
            raise ChatError("chat_not_configured")
        return option

    def _min_interval_s(self, option: ChatModelOption) -> float:
        """Minimum gap between calls for this provider.

        The 12s cap exists for the default provider (Gemini's hard ~5 RPM limit).
        Other providers (e.g. OpenRouter) are not throttled by us, so they get no
        artificial delay.
        """
        if option.provider == "default":
            return self.settings.llm_min_interval_ms / 1000.0
        return 0.0

    def _openai_client(self, option: ChatModelOption):
        import openai

        kwargs: dict = {
            "api_key": option.api_key,
            "timeout": self.settings.llm_timeout_ms / 1000.0,
        }
        if option.base_url:
            kwargs["base_url"] = option.base_url
        return openai.AsyncOpenAI(**kwargs)

    def _kwargs(
        self,
        messages: list[dict],
        tools: list[dict] | None,
        option: ChatModelOption,
    ) -> dict:
        kwargs: dict = {
            "model": option.model,
            "temperature": self.settings.chat_temperature,
            "max_tokens": self.settings.chat_max_tokens,
            "messages": messages,
        }
        if tools:
            kwargs["tools"] = tools
        return kwargs

    async def _create(
        self,
        client,
        messages: list[dict],
        tools: list[dict] | None,
        option: ChatModelOption,
    ):
        """One model request: rate-capped, with bounded backoff on transient
        provider errors. A single call, never a loop."""
        await rate_capped_wait(self._min_interval_s(option))
        return await bounded_retry(
            lambda: client.chat.completions.create(**self._kwargs(messages, tools, option)),
            max_retries=self.settings.llm_max_retries,
            base_delay_s=self.settings.llm_retry_base_ms / 1000.0,
        )

    async def _create_stream(
        self,
        client,
        messages: list[dict],
        tools: list[dict] | None,
        option: ChatModelOption,
    ):
        """Like [_create] but for SSE streaming; still exactly one model request."""
        await rate_capped_wait(self._min_interval_s(option))
        return await bounded_retry(
            lambda: client.chat.completions.create(
                stream=True,
                stream_options={"include_usage": True},
                **self._kwargs(messages, tools, option),
            ),
            max_retries=self.settings.llm_max_retries,
            base_delay_s=self.settings.llm_retry_base_ms / 1000.0,
        )

    async def complete(
        self,
        system: str,
        user: str,
        tools: list[dict] | None = None,
        execute_tool=None,
        model_id: str | None = None,
    ) -> str:
        if not self.settings.chat_enabled:
            raise ChatError("chat_not_configured")
        option = self._resolve(model_id)
        client = self._openai_client(option)
        messages: list[dict] = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]
        for _ in range(MAX_TOOL_ROUNDS):
            try:
                response = await self._create(client, messages, tools, option)
            except Exception as exc:  # network, auth, quota, etc.
                raise ChatError(f"chat_call_failed:{type(exc).__name__}") from exc
            choice = response.choices[0].message
            calls = choice.tool_calls if execute_tool is not None else None
            if calls:
                messages.append(
                    {
                        "role": "assistant",
                        "content": choice.content or "",
                        "tool_calls": _serialize_tool_calls(calls),
                    }
                )
                for call in calls:
                    result = await execute_tool(call.function.name, call.function.arguments)
                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": call.id,
                            "content": json.dumps(result),
                        }
                    )
                continue
            return (choice.content or "").strip()
        return (
            "I could not finish retrieving the details you asked for — "
            "please try again."
        )

    async def complete_stream(
        self,
        system: str,
        user: str,
        tools: list[dict] | None = None,
        execute_tool=None,
        model_id: str | None = None,
    ):
        """Like [complete] but streams. Yields either a text delta (str) or a
        [ToolCall] marker just before each tool executes, then the final text."""
        if not self.settings.chat_enabled:
            raise ChatError("chat_not_configured")
        option = self._resolve(model_id)
        client = self._openai_client(option)
        messages: list[dict] = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]
        for _ in range(MAX_TOOL_ROUNDS):
            try:
                stream = await self._create_stream(client, messages, tools, option)
            except Exception as exc:  # network, auth, quota, etc.
                raise ChatError(f"chat_call_failed:{type(exc).__name__}") from exc

            text_chunks: list[str] = []
            tool_calls: dict[int, dict] = {}
            async for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta
                if not delta:
                    continue
                if delta.content:
                    text_chunks.append(delta.content)
                    yield delta.content
                for call in delta.tool_calls or []:
                    entry = tool_calls.setdefault(
                        call.index,
                        {"id": "", "name": "", "arguments": "", "order": call.index},
                    )
                    if call.id:
                        entry["id"] = call.id
                    if call.function:
                        if call.function.name:
                            entry["name"] += call.function.name
                        if call.function.arguments:
                            entry["arguments"] += call.function.arguments

            if not tool_calls or execute_tool is None:
                return

            ordered = [tool_calls[i] for i in sorted(tool_calls)]
            messages.append(
                {
                    "role": "assistant",
                    "content": "".join(text_chunks) or None,
                    "tool_calls": [
                        {
                            "id": e["id"],
                            "type": "function",
                            "function": {
                                "name": e["name"],
                                "arguments": e["arguments"],
                            },
                        }
                        for e in ordered
                    ],
                }
            )
            for entry in ordered:
                yield ToolCall(entry["name"], entry["arguments"])
                result = await execute_tool(entry["name"], entry["arguments"])
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": entry["id"],
                        "content": json.dumps(result),
                    }
                )
        yield (
            "I could not finish retrieving the details you asked for — "
            "please try again."
        )


def _serialize_tool_calls(calls) -> list[dict]:
    return [
        {
            "id": c.id,
            "type": "function",
            "function": {"name": c.function.name, "arguments": c.function.arguments},
        }
        for c in calls
    ]
