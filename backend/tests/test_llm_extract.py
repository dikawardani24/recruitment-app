from __future__ import annotations

import pytest

from app.config import settings
from app.extraction import LLMExtractError, Profile, extract_profile_text
from app.extraction._orchestrator import _build_prompt, _parse_response


def _profile(**kw) -> Profile:
    base = dict(
        candidate_name="John Doe",
        skills=["python", "docker"],
        years_experience=3.0,
        education="bsc",
        certifications=["PMP"],
        profile_text="cv text",
    )
    base.update(kw)
    return Profile(**base)


def test_extract_profile_text_falls_back_to_rules_when_llm_disabled():
    settings.llm_api_key = None
    profile, source = __import__("asyncio").run(
        extract_profile_text(settings, "John Doe\nSenior Python Engineer", "john.txt")
    )
    assert source == "rules"
    assert profile.candidate_name == "John Doe"


def test_parse_response_uses_llm_values():
    content = (
        '{"candidate_name": "Fathan Azka Pradana", "skills": ["flutter", "dart", "kotlin"],'
        ' "years_experience": 4, "education": "Bachelor of Science",'
        ' "certifications": ["AWS Certified"]}'
    )
    profile = _parse_response(content, "fathan.pdf", "cv", _profile())
    assert profile.candidate_name == "Fathan Azka Pradana"
    assert profile.skills == ["flutter", "dart", "kotlin"]
    assert profile.years_experience == 4.0
    assert profile.education == "bsc"
    assert profile.certifications == ["AWS Certified"]


def test_parse_response_falls_back_per_field():
    content = '{"candidate_name": null, "skills": [], "years_experience": 0, "education": null, "certifications": []}'
    profile = _parse_response(content, "john.txt", "cv", _profile())
    assert profile.candidate_name == "John Doe"
    assert profile.skills == ["python", "docker"]
    assert profile.years_experience == 3.0
    assert profile.education == "bsc"
    assert profile.certifications == ["PMP"]


def test_parse_response_rejects_invalid():
    with pytest.raises(LLMExtractError):
        _parse_response("not json", "john.txt", "cv", _profile())
    with pytest.raises(LLMExtractError):
        _parse_response("not json at all", "john.txt", "cv", _profile())


def test_build_prompt_includes_filename():
    prompt = _build_prompt("Fathan Azka Pradana.pdf", "RESUME CONTENT")
    assert "Fathan Azka Pradana.pdf" in prompt
    assert "RESUME CONTENT" in prompt
