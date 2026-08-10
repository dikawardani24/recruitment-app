from __future__ import annotations

from app.chat import SYSTEM_PROMPT, ChatClient, build_user_prompt
from app.config import Settings
from app.rag._indexer import EmbeddingIndexer
from app.rag._retriever import retrieve_evidence


class Ask:
    """The recruiter-copilot chat turn: retrieve grounded evidence via RAG and
    answer with a recruitment-scoped LLM. Degrades gracefully when the chat LLM
    or the RAG index is not configured."""

    def __init__(
        self,
        settings: Settings,
        chat_client: ChatClient,
        indexer: EmbeddingIndexer | None,
    ):
        self.settings = settings
        self.chat_client = chat_client
        self.indexer = indexer

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
        answer = await self.chat_client.complete(SYSTEM_PROMPT, user_prompt)

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

    @property
    def _retrieval_enabled(self) -> bool:
        return self.indexer is not None and self.indexer.enabled
