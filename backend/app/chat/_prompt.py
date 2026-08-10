from __future__ import annotations

EVIDENCE_CHAR_LIMIT = 500


SYSTEM_PROMPT = """You are the AI recruiter copilot for this applicant-tracking workspace.

SCOPE
- Answer ONLY questions about this workspace's jobs, candidates (CVs), skills,
  experience, education, certifications, rankings, and the recruitment workflow.
- Politely decline questions unrelated to recruitment, hiring, or this workspace
  (general knowledge, coding help, weather, etc.) and steer back to hiring.

GROUNDING (most important)
- Base your answer ONLY on the evidence and conversation provided. Never invent
  candidates, employers, skills, dates, or numbers.
- Cite each claim inline with its [n] evidence number, e.g. "Jane Doe has 7 years
  of Flutter experience [2]".
- If the evidence does not contain enough information, say so explicitly and
  suggest how to get it (e.g. upload more CVs, run reindex).
- Keep answers concise, specific, and useful to a recruiter.

FORMAT
- Plain text with short paragraphs or bullets. Use [n] citations where you rely
  on a specific source.
"""

NO_EVIDENCE_NOTICE = (
    "NO WORKSPACE DATA WAS RETRIEVED (the semantic-search index may be disabled "
    "or empty). Answer only from the conversation if possible; otherwise say the "
    "workspace index is unavailable and suggest enabling/reindexing it."
)


def _format_evidence(index: int, evidence: dict) -> str:
    name = evidence.get("entity_name") or evidence.get("entity_id") or "?"
    section = evidence.get("section") or "profile"
    content = (evidence.get("content") or "").strip()
    if len(content) > EVIDENCE_CHAR_LIMIT:
        content = content[:EVIDENCE_CHAR_LIMIT] + "…"
    return f"[{index}] {evidence.get('entity_type')} \"{name}\" — {section}: {content}"


def build_user_prompt(question: str, evidence: list[dict], history: list[dict]) -> str:
    parts: list[str] = []
    if history:
        lines = [f"{turn.get('role')}: {turn.get('content')}" for turn in history]
        parts.append("CONVERSATION SO FAR:\n" + "\n".join(lines))
    if evidence:
        parts.append(
            "EVIDENCE RETRIEVED FROM THE WORKSPACE:\n"
            + "\n".join(_format_evidence(i + 1, e) for i, e in enumerate(evidence))
        )
    else:
        parts.append(NO_EVIDENCE_NOTICE)
    parts.append(f"QUESTION:\n{question}")
    return "\n\n".join(parts)
