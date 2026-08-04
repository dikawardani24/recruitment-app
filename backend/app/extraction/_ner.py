from __future__ import annotations

import re

from app.config import Settings
from app.extraction._profile import Profile, extract_profile
from app.jd import _extract_education

YEARS_RE = re.compile(r"(\d+(?:\.\d+)?)\s*(?:years?|yrs?|tahun)?", re.I)
DESIGNATION_RE = re.compile(
    r"\b(developer|engineer|designer|consultant|manager|analyst|architect|"
    r"lead|intern|specialist|director|head|officer|founder|recruiter|student)\b",
    re.I,
)
PERSON_RE = re.compile(r"^[A-Za-z][A-Za-z'’.\-]*(?: [A-Za-z][A-Za-z'’.\-]*){1,3}$")


class NERExtractError(Exception):
    pass


def _dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        item = item.strip()
        if item and item.lower() not in seen:
            seen.add(item.lower())
            out.append(item)
    return out


def _looks_like_person(name: str) -> bool:
    name = name.strip()
    return bool(name) and bool(PERSON_RE.match(name)) and not DESIGNATION_RE.search(name)


def profile_from_ner(
    text: str, file_name: str, groups: dict[str, list[str]], fallback: Profile
) -> Profile:
    """Build a Profile from entity groups (entity name -> list of spans).

    ``groups`` is intentionally a plain dict so this can be unit-tested without
    torch/transformers installed.
    """
    ner_name = " ".join(groups.get("Name", [])).strip()
    ner_name_ok = _looks_like_person(ner_name)
    fb_name_ok = _looks_like_person(fallback.candidate_name)
    if ner_name_ok and (
        not fb_name_ok or len(ner_name.split()) >= len(fallback.candidate_name.split())
    ):
        name = ner_name
    else:
        name = fallback.candidate_name or ner_name

    skills = _dedupe(groups.get("Skills", []) + fallback.skills)
    if not skills:
        skills = fallback.skills

    years = 0.0
    for span in groups.get("Years of Experience", []):
        m = YEARS_RE.search(span)
        if m:
            years = max(0.0, float(m.group(1)))
            break
    if years <= 0:
        years = fallback.years_experience

    degree = groups.get("Degree", [])
    education = _extract_education(degree[0]) if degree else None
    if not education:
        education = fallback.education

    return Profile(
        candidate_name=name,
        skills=skills,
        years_experience=years,
        education=education,
        certifications=fallback.certifications,
        profile_text=text,
    )


_pipeline = None


def _load_pipeline(settings: Settings):
    global _pipeline
    if _pipeline is not None:
        return _pipeline
    try:
        from transformers import pipeline
    except ImportError as exc:  # torch/transformers not installed
        raise NERExtractError("ml_deps_missing") from exc

    try:
        _pipeline = pipeline(
            "token-classification",
            model=settings.ner_model,
            aggregation_strategy="simple",
            device=-1,
        )
    except Exception as exc:
        raise NERExtractError(f"ner_load_failed:{type(exc).__name__}") from exc
    return _pipeline


def extract_profile_ner(settings: Settings, text: str, file_name: str) -> Profile:
    """Extract a structured profile with a local BERT resume-NER model.
    Raises NERExtractError on failure so the caller can fall back."""
    if not settings.ner_enabled:
        raise NERExtractError("ner_not_enabled")

    ner = _load_pipeline(settings)
    fallback = extract_profile(text, file_name)

    try:
        results = ner(text[:8000])
    except Exception as exc:
        raise NERExtractError(f"ner_call_failed:{type(exc).__name__}") from exc

    groups: dict[str, list[str]] = {}
    for item in results:
        entity = item.get("entity_group") or item.get("entity")
        if not entity or item.get("score", 1.0) < settings.ner_confidence:
            continue
        groups.setdefault(entity, []).append(str(item.get("word") or ""))

    return profile_from_ner(text, file_name, groups, fallback)
