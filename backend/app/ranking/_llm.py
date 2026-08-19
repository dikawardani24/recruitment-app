from __future__ import annotations

import json
import re
from dataclasses import dataclass

from app.config import Settings
from app.llm._gate import bounded_retry


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
    classification: str = "MET"

    def as_dict(self) -> dict:
        return {
            "rank": self.rank,
            "overall": self.overall,
            "recommendation": self.recommendation,
            "explanation": self.explanation,
            "strengths": self.strengths,
            "weaknesses": self.weaknesses,
            "classification": self.classification,
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
      "candidate": 1,
      "rank": 1,
      "overall": 0.95,
      "classification": "MET | PARTIALLY_MET | NOT_MET",
      "recommendation": "strong_match | good_match | possible_match | weak_match",
      "explanation": "2-3 sentence reasoning",
      "strengths": ["..."],
      "weaknesses": ["..."]
    }}
  ]
}}

Rules:
- "candidate" is the NUMBER of the candidate from the list above (1-based), not the name.
- Include exactly {len(candidates)} entries, one per candidate.
- "classification" reflects how well the candidate's professional background matches
  the job: MET = directly relevant, PARTIALLY_MET = relevant domain but missing key
  requirements, NOT_MET = fundamentally unrelated to the job (set "overall" to 0.0).
- Do NOT treat generic traits (communication, management, leadership, teamwork) as
  evidence of relevance on their own; the candidate needs real professional overlap.
"""


async def rank_with_llm(
    settings: Settings,
    job: dict,
    candidates: list[dict],
    api_key: str,
    model: str,
    base_url: str | None = None,
) -> list[LLMReasoning]:
    """Rank candidates with an LLM. Raises LLMRankingError on any failure so the
    caller can fall back to other providers or deterministic scoring."""
    import openai

    kwargs: dict = {
        "api_key": api_key,
        "timeout": settings.llm_timeout_ms / 1000.0,
    }
    if base_url:
        kwargs["base_url"] = base_url
    client = openai.AsyncOpenAI(**kwargs)

    try:
        response = await bounded_retry(
            lambda: client.chat.completions.create(
                model=model,
                temperature=0.2,
                messages=[
                    {
                        "role": "system",
                        "content": "You are a precise, JSON-only assistant.",
                    },
                    {"role": "user", "content": _build_prompt(job, candidates)},
                ],
            ),
            max_retries=settings.llm_max_retries,
            base_delay_s=settings.llm_retry_base_ms / 1000.0,
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

    by_name: dict[str, list[int]] = {}
    for idx, c in enumerate(candidates):
        by_name.setdefault(c["candidate_name"].lower(), []).append(idx)

    entries: dict[int, LLMReasoning] = {}
    for item in data.get("candidates", []):
        idx = _resolve_candidate_idx(item.get("candidate"), by_name, len(candidates))
        if idx is None:
            continue
        try:
            overall = float(item.get("overall", 0.0))
        except (TypeError, ValueError):
            overall = 0.0
        entries[idx] = LLMReasoning(
            rank=int(item.get("rank", 0)),
            overall=max(0.0, min(1.0, overall)),
            recommendation=str(item.get("recommendation", "possible_match")),
            explanation=str(item.get("explanation", "")),
            strengths=[str(s) for s in item.get("strengths", [])],
            weaknesses=[str(w) for w in item.get("weaknesses", [])],
            classification=str(item.get("classification", "MET")),
        )

    if len(entries) != len(candidates):
        raise LLMRankingError("llm_incomplete_ranking")
    return [entries[i] for i in range(len(candidates))]


def _resolve_candidate_idx(
    raw, by_name: dict[str, list[int]], n_candidates: int
) -> int | None:
    """Resolve the model's ``candidate`` reference to a 0-based index.

    Prefers the 1-based number; falls back to a unique name match. Returns None
    for ambiguous/missing references."""
    if isinstance(raw, int):
        idx = raw - 1
        if 0 <= idx < n_candidates:
            return idx
        return None
    if isinstance(raw, str):
        s = raw.strip()
        if s.isdigit():
            idx = int(s) - 1
            if 0 <= idx < n_candidates:
                return idx
            return None
        matches = by_name.get(s.lower(), [])
        if len(matches) == 1:
            return matches[0]
    return None
