from __future__ import annotations

import json
import re
from dataclasses import dataclass

from app.config import Settings


class LLMRankingError(Exception):
    pass


@dataclass
class LLMReasoning:
    rank: int
    overall: float
    recommendation: str
    explanation: str
    strengths: list[str]
    weaknesses: list[str]

    def as_dict(self) -> dict:
        return {
            "rank": self.rank,
            "overall": self.overall,
            "recommendation": self.recommendation,
            "explanation": self.explanation,
            "strengths": self.strengths,
            "weaknesses": self.weaknesses,
        }


def _build_prompt(job: dict, candidates: list[dict]) -> str:
    job_lines = "\n".join(
        f"- {k}: {v}" for k, v in job.items() if v not in (None, "", [], {})
    )
    candidate_lines = []
    for i, c in enumerate(candidates, start=1):
        candidate_lines.append(
            f"{i}. {c['candidate_name']}\n"
            f"   Skills: {', '.join(c['skills']) or 'n/a'}\n"
            f"   Years experience: {c['years_experience']}\n"
            f"   Education: {c['education'] or 'n/a'}\n"
            f"   Certifications: {', '.join(c['certifications']) or 'n/a'}"
        )
    return f"""
You are a senior technical recruiter. Rank the following candidates against the job
requirements and produce honest, specific reasoning for each. Focus on skills fit,
relevant experience, and any gaps. A candidate with strong skills but fewer years is
still competitive ("hidden gem").

JOB REQUIREMENTS:
{job_lines}

CANDIDATES:
{chr(10).join(candidate_lines)}

Respond with ONLY a JSON object in this exact shape (no markdown):
{{
  "candidates": [
    {{
      "candidate": "exact candidate name",
      "rank": 1,
      "overall": 0.95,
      "recommendation": "strong_match | good_match | possible_match | weak_match",
      "explanation": "2-3 sentence reasoning",
      "strengths": ["..."],
      "weaknesses": ["..."]
    }}
  ]
}}
"""


async def rank_with_llm(settings: Settings, job: dict, candidates: list[dict]) -> list[LLMReasoning]:
    """Rank candidates with an LLM. Raises LLMRankingError on any failure so the
    caller can fall back to deterministic scoring."""
    if not settings.llm_enabled:
        raise LLMRankingError("llm_not_configured")

    import openai

    kwargs: dict = {
        "api_key": settings.llm_api_key,
        "timeout": settings.llm_timeout_ms / 1000.0,
    }
    if settings.llm_base_url:
        kwargs["base_url"] = settings.llm_base_url
    client = openai.AsyncOpenAI(**kwargs)

    try:
        response = await client.chat.completions.create(
            model=settings.llm_model,
            temperature=0.2,
            messages=[
                {
                    "role": "system",
                    "content": "You are a precise, JSON-only assistant.",
                },
                {"role": "user", "content": _build_prompt(job, candidates)},
            ],
        )
    except Exception as exc:  # network, auth, quota, etc.
        raise LLMRankingError(f"llm_call_failed:{type(exc).__name__}") from exc

    content = response.choices[0].message.content or ""
    return _parse_response(content, candidates)


def _parse_response(content: str, candidates: list[dict]) -> list[LLMReasoning]:
    match = re.search(r"\{.*\}", content, re.DOTALL)
    if not match:
        raise LLMRankingError("llm_invalid_response")
    try:
        data = json.loads(match.group(0))
    except json.JSONDecodeError as exc:
        raise LLMRankingError("llm_invalid_json") from exc

    by_name = {c["candidate_name"].lower(): c for c in candidates}
    out: list[LLMReasoning] = []
    for item in data.get("candidates", []):
        name = str(item.get("candidate", "")).strip()
        candidate = by_name.get(name.lower())
        if candidate is None and by_name:
            candidate = by_name.get(next(iter(by_name)))
        if candidate is None:
            continue
        try:
            overall = float(item.get("overall", 0.0))
        except (TypeError, ValueError):
            overall = 0.0
        out.append(
            LLMReasoning(
                rank=int(item.get("rank", 0)),
                overall=max(0.0, min(1.0, overall)),
                recommendation=str(item.get("recommendation", "possible_match")),
                explanation=str(item.get("explanation", "")),
                strengths=[str(s) for s in item.get("strengths", [])],
                weaknesses=[str(w) for w in item.get("weaknesses", [])],
            )
        )
    if not out:
        raise LLMRankingError("llm_empty_result")
    return out
