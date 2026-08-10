from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException
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


@router.post("/chat")
async def chat(payload: ChatRequest) -> dict:
    """Recruiter-copilot Q&A. Retrieves grounded evidence via RAG and answers
    with a recruitment-scoped system prompt. Returns `configured: false` when no
    LLM key is set; answers from evidence only when RAG is enabled."""
    history = [
        {"role": turn.role, "content": turn.content}
        for turn in payload.history[-settings.chat_history_turns:]
    ]
    try:
        return await ask_use_case().execute(
            question=payload.question,
            job_id=payload.job_id,
            history=history,
            top_k=payload.top_k,
        )
    except ChatError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
