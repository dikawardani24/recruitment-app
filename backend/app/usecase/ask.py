from __future__ import annotations

from app.chat import (
    SYSTEM_PROMPT,
    ChatClient,
    ChatError,
    ToolCall,
    ToolError,
    ToolRegistry,
    build_user_prompt,
)
from app.config import Settings
from app.rag._indexer import EmbeddingIndexer
from app.rag._retriever import retrieve_evidence


class Ask:
    """The recruiter-copilot chat turn: retrieve grounded evidence via RAG,
    answer with a recruitment-scoped LLM, and use registered tools to look up
    full workspace records when asked. Degrades gracefully when the chat LLM or
    the RAG index is not configured."""

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
            return {
                "configured": False,
                "answer": (
                    "Chat is not configured. Set ATS_LLM__API_KEY (or "
                    "GEMINI_API_KEY / OPENAI_API_KEY) to enable the recruiter copilot."
                ),
                "sources": [],
                "retrieval": {"enabled": False, "count": 0},
            }
        if not question:
            return {
                "configured": True,
                "answer": "",
                "sources": [],
                "retrieval": {"enabled": self._retrieval_enabled, "count": 0},
            }

        evidence = []
        if self._retrieval_enabled:
            evidence = await retrieve_evidence(
                self.indexer,
                question,
                job_id=job_id,
                top_k=top_k,
            )

        user_prompt = build_user_prompt(
            question,
            [item.as_dict() for item in evidence],
            history or [],
        )
        answer = await self.chat_client.complete(
            SYSTEM_PROMPT,
            user_prompt,
            tools=self._tool_specs,
            execute_tool=self._run_tool,
        )

        return {
            "configured": True,
            "answer": answer,
            "sources": [item.as_dict() for item in evidence],
            "retrieval": {
                "enabled": self._retrieval_enabled,
                "job_id": job_id,
                "query": question,
                "count": len(evidence),
            },
        }

    async def stream(
        self,
        question: str,
        job_id: str | None = None,
        history: list[dict] | None = None,
        top_k: int = 10,
    ):
        """Streaming variant of [execute]. Yields event dicts consumed by the
        SSE endpoint:
          {"type": "text", "content": "..."}     incremental answer text
          {"type": "tool", "name": "..."}        a tool is about to run
          {"type": "done", "configured": ..., "answer": "...", "sources": [...]}
          {"type": "error", "message": "..."}    terminal failure
        """
        question = (question or "").strip()
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
            yield {
                "type": "done",
                "configured": True,
                "answer": "",
                "sources": [],
                "retrieval": {"enabled": self._retrieval_enabled, "count": 0},
            }
            return

        evidence = []
        if self._retrieval_enabled:
            evidence = await retrieve_evidence(
                self.indexer,
                question,
                job_id=job_id,
                top_k=top_k,
            )

        user_prompt = build_user_prompt(
            question,
            [item.as_dict() for item in evidence],
            history or [],
        )

        text_parts: list[str] = []
        try:
            async for item in self.chat_client.complete_stream(
                SYSTEM_PROMPT,
                user_prompt,
                tools=self._tool_specs,
                execute_tool=self._run_tool,
            ):
                if isinstance(item, ToolCall):
                    yield {"type": "tool", "name": item.name}
                elif item:
                    text_parts.append(item)
                    yield {"type": "text", "content": item}
        except ChatError as exc:
            yield {"type": "error", "message": str(exc)}
            return

        yield {
            "type": "done",
            "configured": True,
            "answer": "".join(text_parts),
            "sources": [item.as_dict() for item in evidence],
            "retrieval": {
                "enabled": self._retrieval_enabled,
                "job_id": job_id,
                "query": question,
                "count": len(evidence),
            },
        }

    @property
    def _retrieval_enabled(self) -> bool:
        return self.indexer is not None and self.indexer.enabled

    @property
    def _tool_specs(self) -> list[dict]:
        return self.tools.specs() if self.tools else []

    async def _run_tool(self, name: str, arguments: str) -> dict:
        if self.tools is None:
            return {"error": "no_tools_available"}
        try:
            return await self.tools.execute(name, arguments)
        except ToolError as exc:
            return {"error": str(exc)}
        except Exception as exc:  # repo/db failures must not kill the chat turn
            return {"error": f"tool_error:{type(exc).__name__}"}
