from __future__ import annotations

import logging
import time
from typing import AsyncIterator

from app.chat import (
    GENERAL_SYSTEM_PROMPT,
    SYSTEM_PROMPT,
    ChatClient,
    ChatError,
    ToolCall,
    ToolError,
    ToolRegistry,
    QueryRoute,
    QueryRouter,
    build_reasoning_prompt,
    deterministic_answer,
    prefetch_records,
)
from app.config import Settings
from app.rag._indexer import EmbeddingIndexer
from app.rag._retriever import retrieve_evidence

logger = logging.getLogger("ats.chat")

_CHITCHAT_REPLIES = {
    "greeting": (
        "Hello! I'm your recruiter copilot. Ask me about your applicants, jobs, "
        "rankings, or whether any candidate fits a position."
    ),
    "thanks": "You're welcome! Happy to help — ask me anything about your workspace.",
}

def _status(stage: str, message: str) -> dict:
    return {"type": "status", "stage": stage, "message": message}


def _friendly_error(raw: str) -> str:
    """Human-friendly error text for the SSE stream. Never exposes provider
    names, rate limits, retry counts, or internal class names."""
    lower = raw.lower()
    if any(
        token in lower
        for token in (
            "ratelimit",
            "rate_limit",
            "429",
            "quota",
            "too many requests",
            "resourceexhausted",
        )
    ):
        return "You have reached the limit, please try again later."
    return (
        "Our system is facing a technical issue. "
        "Please contact the system administrator or try again later."
    )


def _ms_since(started: float) -> int:
    return int((time.monotonic() - started) * 1000)


async def _timed(name: str, coro, timing: dict[str, int] | None):
    started = time.monotonic()
    result = await coro
    if timing is not None:
        timing[name] = _ms_since(started)
    return result


def _log_stream_timing(route: "QueryRoute", timing: dict[str, int], total_ms: int) -> None:
    parts = [f"{key}={value}ms" for key, value in timing.items()] + [f"total={total_ms}ms"]
    logger.info(
        "chat stream done mode=%s intent=%s %s",
        route.mode,
        route.intent,
        " ".join(parts),
    )


class Ask:
    """The recruiter-copilot chat turn.

    Gemini is a hard 5 RPM resource, so every turn is routed FIRST by a
    deterministic router (no LLM):

    - ``chitchat`` / ``deterministic`` -> answered with ZERO Gemini calls.
      Deterministic answers are produced from the API tools (jobs, candidates,
      rankings) only.
    - ``rag_reasoning`` -> workspace data is pre-fetched (RAG evidence + API
      tool records) and ONE Gemini call reasons over it. Gemini never calls the
      tools itself, so a single user request can never trigger a multi-round
      tool-calling loop.
    - ``general`` -> one Gemini call, no tools, no retrieval.
    """

    def __init__(
        self,
        settings: Settings,
        chat_client: ChatClient,
        indexer: EmbeddingIndexer | None,
        tools: ToolRegistry | None = None,
    ):
        self.settings = settings
        self.chat_client = chat_client
        self.indexer = indexer
        self.tools = tools

    async def execute(
        self,
        question: str,
        job_id: str | None = None,
        history: list[dict] | None = None,
        top_k: int = 10,
    ) -> dict:
        question = (question or "").strip()
        if not self.settings.chat_enabled:
            return self._not_configured()
        if not question:
            return self._empty(question)

        route = QueryRouter.route(question, history)

        if route.mode == "chitchat":
            answer = self._chitchat(question)
            return self._answer(route, answer, [], job_id, question)

        if route.mode == "deterministic":
            return await self._deterministic(route, question, job_id, history)

        if route.mode == "general":
            answer = await self.chat_client.complete(
                GENERAL_SYSTEM_PROMPT, question, tools=None
            )
            return self._answer(route, answer, [], job_id, question)

        # rag_reasoning
        evidence, records = await self._collect(
            route, question, job_id, top_k
        )
        user_prompt = build_reasoning_prompt(
            question,
            [item.as_dict() for item in evidence],
            history or [],
            records,
        )
        answer = await self.chat_client.complete(
            SYSTEM_PROMPT, user_prompt, tools=None
        )
        return self._answer(
            route,
            answer,
            [item.as_dict() for item in evidence],
            job_id,
            question,
            count=len(evidence),
        )

    async def stream(
        self,
        question: str,
        job_id: str | None = None,
        history: list[dict] | None = None,
        top_k: int = 10,
    ) -> AsyncIterator[dict]:
        """Streaming variant of [execute]. Yields SSE event dicts:
          {"type": "started", ...}
          {"type": "status", "stage": ..., "message": ...}
          {"type": "text", "content": ...}
          {"type": "done", ...}
          / {"type": "error", ...}

        Every status event maps to a real backend stage; no synthetic progress.
        """
        question = (question or "").strip()
        timing: dict[str, int] = {}
        t_request = time.monotonic()

        if not self.settings.chat_enabled:
            yield {
                "type": "error",
                "message": (
                    "Chat is not configured. Set ATS_LLM__API_KEY (or "
                    "GEMINI_API_KEY / OPENAI_API_KEY) to enable the recruiter copilot."
                ),
            }
            return
        if not question:
            yield {"type": "done", "configured": True, "answer": "", "sources": []}
            return

        # First SSE event, emitted immediately after the connection is up.
        yield {"type": "started"}
        timing["connected"] = _ms_since(t_request)

        yield _status("routing", "Understanding your request...")
        t_stage = time.monotonic()
        route = QueryRouter.route(question, history)
        timing["routing"] = _ms_since(t_stage)

        if route.mode == "chitchat":
            yield _status("answering", "Preparing your response...")
            answer = self._chitchat(question)
            yield {"type": "text", "content": answer}
            yield {"type": "done", "configured": True, "answer": answer, "sources": []}
            _log_stream_timing(route, timing, _ms_since(t_request))
            return

        if route.mode == "deterministic":
            yield _status("retrieving", "Finding the relevant information...")
            try:
                answer, sources = await deterministic_answer(route, self.tools)
            except ToolError:
                logger.exception(
                    "chat deterministic lookup failed mode=%s intent=%s",
                    route.mode,
                    route.intent,
                )
                yield {"type": "error", "message": "I couldn't look that up right now."}
                return
            timing["collect"] = _ms_since(t_request) - timing.get("routing", 0)
            yield _status("preparing", "Preparing the results...")
            yield {"type": "text", "content": answer}
            yield {"type": "done", "configured": True, "answer": answer, "sources": sources}
            _log_stream_timing(route, timing, _ms_since(t_request))
            return

        if route.mode == "general":
            yield _status("reasoning", "Preparing your answer...")
            text_parts: list[str] = []
            try:
                async for item in self.chat_client.complete_stream(
                    GENERAL_SYSTEM_PROMPT, question, tools=None
                ):
                    if item:
                        if not text_parts:
                            timing["first_token"] = _ms_since(t_request)
                        text_parts.append(item)
                        yield {"type": "text", "content": item}
            except ChatError as exc:
                logger.exception(
                    "chat general turn failed mode=%s intent=%s error=%s",
                    route.mode,
                    route.intent,
                    exc,
                )
                yield {"type": "error", "message": _friendly_error(str(exc))}
                return
            timing["gemini"] = _ms_since(t_request) - timing.get("first_token", t_request)
            yield {
                "type": "done",
                "configured": True,
                "answer": "".join(text_parts),
                "sources": [],
            }
            _log_stream_timing(route, timing, _ms_since(t_request))
            return

        # rag_reasoning: pre-fetch data, then exactly ONE Gemini call.
        yield _status("retrieving", "Searching relevant candidates and jobs...")
        evidence, records = await self._collect(
            route, question, job_id, top_k, timing
        )
        yield _status("preparing", "Preparing the relevant information...")
        t_stage = time.monotonic()
        user_prompt = build_reasoning_prompt(
            question,
            [item.as_dict() for item in evidence],
            history or [],
            records,
        )
        timing["prompt"] = _ms_since(t_stage)
        yield _status("reasoning", "Comparing the relevant information...")
        text_parts: list[str] = []
        try:
            async for item in self.chat_client.complete_stream(
                SYSTEM_PROMPT, user_prompt, tools=None
            ):
                if isinstance(item, ToolCall):
                    yield {"type": "tool", "name": item.name}
                elif item:
                    if not text_parts:
                        timing["first_token"] = _ms_since(t_request)
                    text_parts.append(item)
                    yield {"type": "text", "content": item}
        except ChatError as exc:
            logger.exception(
                "chat rag_reasoning turn failed mode=%s intent=%s error=%s",
                route.mode,
                route.intent,
                exc,
            )
            yield {"type": "error", "message": _friendly_error(str(exc))}
            return
        timing["gemini"] = _ms_since(t_request) - timing.get("first_token", t_request)
        yield {
            "type": "done",
            "configured": True,
            "answer": "".join(text_parts),
            "sources": [item.as_dict() for item in evidence],
        }
        _log_stream_timing(route, timing, _ms_since(t_request))

    # --- helpers ---

    async def _collect(
        self,
        route: QueryRoute,
        question: str,
        job_id: str | None,
        top_k: int,
        timing: dict[str, int] | None = None,
    ):
        evidence = []
        if self._retrieval_enabled and route.search_query:
            evidence = await _timed(
                "retrieve",
                retrieve_evidence(
                    self.indexer, route.search_query, job_id=job_id, top_k=top_k
                ),
                timing,
            )
        records = {}
        if self.tools is not None:
            try:
                records = await _timed(
                    "prefetch",
                    prefetch_records(route, self.tools, job_id),
                    timing,
                )
            except (ToolError, ChatError):
                logger.warning(
                    "chat record prefetch failed mode=%s intent=%s",
                    route.mode,
                    route.intent,
                    exc_info=True,
                )
                records = {}
        return evidence, records

    async def _deterministic(
        self,
        route: QueryRoute,
        question: str,
        job_id: str | None,
        history: list[dict] | None,
    ) -> dict:
        if self.tools is None:
            # No API tools available: fall back to the single-Gemini grounded path.
            user_prompt = build_reasoning_prompt(question, [], history, None)
            answer = await self.chat_client.complete(
                SYSTEM_PROMPT, user_prompt, tools=None
            )
            return self._answer(route, answer, [], job_id, question)
        answer, sources = await deterministic_answer(route, self.tools)
        return self._answer(route, answer, sources, job_id, question)

    def _chitchat(self, question: str) -> str:
        if question.lower().startswith(("thanks", "thank you", "thx", "ty")):
            return _CHITCHAT_REPLIES["thanks"]
        return _CHITCHAT_REPLIES["greeting"]

    def _answer(
        self,
        route: QueryRoute,
        answer: str,
        sources: list[dict],
        job_id: str | None,
        query: str,
        count: int | None = None,
    ) -> dict:
        return {
            "configured": True,
            "answer": answer,
            "sources": sources,
            "retrieval": {
                "enabled": self._retrieval_enabled,
                "job_id": job_id,
                "query": query,
                "count": count if count is not None else len(sources),
            },
        }

    def _not_configured(self) -> dict:
        return {
            "configured": False,
            "answer": (
                "Chat is not configured. Set ATS_LLM__API_KEY (or "
                "GEMINI_API_KEY / OPENAI_API_KEY) to enable the recruiter copilot."
            ),
            "sources": [],
            "retrieval": {"enabled": False, "count": 0},
        }

    def _empty(self, question: str) -> dict:
        return {
            "configured": True,
            "answer": "",
            "sources": [],
            "retrieval": {"enabled": self._retrieval_enabled, "count": 0},
        }

    @property
    def _retrieval_enabled(self) -> bool:
        return self.indexer is not None and self.indexer.enabled
