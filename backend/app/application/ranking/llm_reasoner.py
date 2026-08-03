from __future__ import annotations

import json

from app.application.ranking.ranking_engine import SearchIntent
from app.core.ports import LLMProvider
from app.domain.entities import Candidate, CandidateRanking, VectorHit

_SYSTEM = """\
You are a recruiting analyst. You receive ONE candidate's structured profile and
a set of evidence chunks retrieved from their resume. You must reason ONLY from
this provided information. Do not use any outside knowledge about the person.

Rules:
- Never claim something that is not supported by the evidence chunks or the profile.
- Cite evidence using their chunk ids. Every strength/weakness must map to >=1 chunk id.
- Return ONLY valid JSON in this exact shape:
{
  "strengths": ["..."],
  "weaknesses": ["..."],
  "explanation": "...",
  "recommendation": "...",
  "evidence_chunk_ids": ["chunk-id", ...]
}
- evidence_chunk_ids must be a subset of the chunk ids given to you.
"""


class EvidenceConstrainedReasoner:
    def __init__(self, llm: LLMProvider) -> None:
        self._llm = llm

    async def explain(
        self,
        candidate: Candidate,
        intent: SearchIntent,
        hits: list[VectorHit],
        ranking: CandidateRanking,
    ) -> CandidateRanking | None:
        chunk_lines = "\n".join(
            f"[{h.chunk_id}] ({h.section.value}) score={h.score:.2f}: {h.text[:400]}" for h in hits
        )
        available = {str(h.chunk_id) for h in hits}

        profile = {
            "name": candidate.name,
            "summary": candidate.summary,
            "skills": candidate.profile.skills,
            "years_experience": candidate.derived_metrics.get("years_experience"),
            "certifications": [c.name for c in candidate.profile.certifications],
        }

        user = (
            f"Job intent: {intent}\n\n"
            f"Candidate profile: {json.dumps(profile)}\n\n"
            f"Evidence chunks:\n{chunk_lines}\n\n"
            "Provide strengths, weaknesses, explanation, recommendation and evidence_chunk_ids."
        )

        raw = await self._llm.complete(_SYSTEM, user, json_mode=True, temperature=0.0)
        data = self._parse(raw)
        if data is None:
            return None

        cited = {c for c in data.get("evidence_chunk_ids", []) if c in available}
        data["evidence_chunk_ids"] = list(cited)

        ranking.strengths = data.get("strengths", [])[:5]
        ranking.weaknesses = data.get("weaknesses", [])[:5]
        ranking.explanation = data.get("explanation", "")
        ranking.recommendation = data.get("recommendation", "")
        ranking.evidence = [h for h in hits if str(h.chunk_id) in cited]
        return ranking

    @staticmethod
    def _parse(raw: str) -> dict | None:
        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            start = raw.find("{")
            end = raw.rfind("}")
            if start >= 0 and end > start:
                try:
                    return json.loads(raw[start : end + 1])
                except json.JSONDecodeError:
                    return None
        return None
