from __future__ import annotations

import asyncio
import json
import re

from app.config import Settings
from app.jd import _extract_education
from app.ner_extract import NERExtractError
from app.ranking import Profile, extract_profile


class LLMExtractError(Exception):
    pass


MAX_EXTRACT_CHARS = 8000


def _build_prompt(file_name: str, text: str) -> str:
    return f"""You are an expert resume parser. Extract structured candidate data from the resume below.

Resume filename: {file_name or "unknown"}
(If the filename contains a person's name, that is usually the candidate name.)

RESUME TEXT:
{text}

Return ONLY a JSON object (no markdown) with exactly this shape:
{{
  "candidate_name": "string or null",
  "skills": ["skill", "..."],
  "years_experience": 0.0,
  "education": "string or null",
  "certifications": ["cert", "..."]
}}

Rules:
- candidate_name: full name; names may be letter-spaced (e.g. "F A T H A N A Z K A" = "Fathan Azka"); use the filename as a hint; null if you cannot tell.
- skills: every technical and soft skill explicitly mentioned (do not invent).
- years_experience: total years of professional experience as a number; 0.0 if not stated.
- education: the highest degree as plain text (e.g. "Bachelor of Science", "Master of Science", "PhD", "Diploma"); null if not stated.
- certifications: recognized professional certifications (e.g. AWS Certified, PMP, CISSP); empty list if none.
"""


def _parse_response(content: str, file_name: str, text: str, fallback: Profile) -> Profile:
    match = re.search(r"\{.*\}", content, re.DOTALL)
    if not match:
        raise LLMExtractError("llm_invalid_response")
    try:
        data = json.loads(match.group(0))
    except json.JSONDecodeError as exc:
        raise LLMExtractError("llm_invalid_json") from exc

    name = str(data.get("candidate_name") or "").strip() or fallback.candidate_name

    skills = [str(s).strip() for s in (data.get("skills") or []) if str(s).strip()]
    if not skills:
        skills = fallback.skills

    years_raw = data.get("years_experience")
    try:
        years = float(years_raw) if years_raw not in (None, "") else 0.0
    except (TypeError, ValueError):
        years = 0.0
    years = max(0.0, min(100.0, years))
    if years <= 0:
        years = fallback.years_experience

    education = str(data.get("education") or "").strip() or None
    education = _extract_education(education) if education else None
    if not education:
        education = fallback.education

    certifications = [
        str(c).strip() for c in (data.get("certifications") or []) if str(c).strip()
    ]
    if not certifications:
        certifications = fallback.certifications

    return Profile(
        candidate_name=name,
        skills=skills,
        years_experience=years,
        education=education,
        certifications=certifications,
        profile_text=text,
    )


async def extract_profile_with_llm(settings: Settings, text: str, file_name: str) -> Profile:
    """Extract a structured profile with an LLM. Raises LLMExtractError on failure
    so the caller can fall back to deterministic parsing."""
    if not settings.llm_enabled:
        raise LLMExtractError("llm_not_configured")

    import openai

    kwargs: dict = {
        "api_key": settings.llm_api_key,
        "timeout": settings.llm_timeout_ms / 1000.0,
    }
    if settings.llm_base_url:
        kwargs["base_url"] = settings.llm_base_url
    client = openai.AsyncOpenAI(**kwargs)

    fallback = extract_profile(text, file_name)

    try:
        response = await client.chat.completions.create(
            model=settings.llm_model,
            temperature=0.0,
            messages=[
                {"role": "system", "content": "You are a precise, JSON-only assistant."},
                {
                    "role": "user",
                    "content": _build_prompt(file_name, text[:MAX_EXTRACT_CHARS]),
                },
            ],
        )
    except Exception as exc:  # network, auth, quota, etc.
        raise LLMExtractError(f"llm_call_failed:{type(exc).__name__}") from exc

    content = response.choices[0].message.content or ""
    return _parse_response(content, file_name, text, fallback)


async def extract_profile_text(
    settings: Settings, text: str, file_name: str
) -> tuple[Profile, str]:
    """Extraction priority: local NER -> LLM -> deterministic rules."""
    if settings.ner_enabled:
        try:
            from app.ner_extract import extract_profile_ner

            return await asyncio.to_thread(
                extract_profile_ner, settings, text, file_name
            ), "ner"
        except NERExtractError:
            pass
    if settings.llm_enabled:
        try:
            return await extract_profile_with_llm(settings, text, file_name), "llm"
        except LLMExtractError:
            pass
    return extract_profile(text, file_name), "rules"
