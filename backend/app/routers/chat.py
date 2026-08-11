from __future__ import annotations

import json
from typing import Literal

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.chat import ChatError
from app.config import settings
from app.di.injection import ask_use_case

router = APIRouter(tags=["chat"])


class ChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)
    job_id: str | None = None
    history: list[ChatTurn] = Field(default_factory=list)
    top_k: int = Field(10, ge=1, le=50)
    model: str | None = None


def _history(payload: ChatRequest) -> list[dict]:
    return [
        {"role": turn.role, "content": turn.content}
        for turn in payload.history[-settings.chat_history_turns:]
    ]


@router.get("/chat/models")
async def chat_models() -> dict:
    """Available recruiter-copilot chat models (default endpoint + OpenRouter)."""
    return {
        "models": [
            {
                "id": option.id,
                "label": option.label,
                "provider": option.provider,
                "model": option.model,
            }
            for option in settings.chat_models
        ]
    }


@router.post("/chat")
async def chat(payload: ChatRequest) -> dict:
    """Recruiter-copilot Q&A. Retrieves grounded evidence via RAG and answers
    with a recruitment-scoped system prompt. Returns `configured: false` when no
    LLM key is set; answers from evidence only when RAG is enabled."""
    try:
        return await ask_use_case().execute(
            question=payload.question,
            job_id=payload.job_id,
            history=_history(payload),
            top_k=payload.top_k,
            model_id=payload.model,
        )
    except ChatError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.post("/chat/stream")
async def chat_stream(payload: ChatRequest) -> StreamingResponse:
    """SSE streaming chat. Emits `data: {...}` frames: incremental answer text,
    optional `tool` events while the copilot queries workspace records, and a
    final `done` (with sources) or `error` event."""

    async def events():
        async for event in ask_use_case().stream(
            question=payload.question,
            job_id=payload.job_id,
            history=_history(payload),
            top_k=payload.top_k,
            model_id=payload.model,
        ):
            yield f"data: {json.dumps(event)}\n\n"

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

