from __future__ import annotations

from app.extraction import Profile
from app.extraction._ner import _dedupe, profile_from_ner


def _profile(**kw) -> Profile:
    base = dict(
        candidate_name="Fathan Azka",
        skills=["flutter"],
        years_experience=2.0,
        education="bsc",
        certifications=["AWS Certified"],
        profile_text="cv text",
    )
    base.update(kw)
    return Profile(**base)


def test_profile_from_ner_uses_entity_values():
    groups = {
        "Name": ["Fathan", "Azka Pradana"],
        "Skills": ["Flutter", "Dart", "Flutter"],
        "Degree": ["Bachelor of Science in Computer Science"],
        "Years of Experience": ["5 years"],
    }
    profile = profile_from_ner("cv", "fathan.pdf", groups, _profile())
    assert profile.candidate_name == "Fathan Azka Pradana"
    assert profile.skills == ["Flutter", "Dart"]
    assert profile.years_experience == 5.0
    assert profile.education == "bsc"
    assert profile.certifications == ["AWS Certified"]


def test_profile_from_ner_falls_back_per_field():
    groups: dict[str, list[str]] = {}
    profile = profile_from_ner("cv", "fathan.pdf", groups, _profile())
    assert profile.candidate_name == "Fathan Azka"
    assert profile.skills == ["flutter"]
    assert profile.years_experience == 2.0
    assert profile.education == "bsc"


def test_years_parsing():
    groups = {"Years of Experience": ["More than 4+ years"]}
    profile = profile_from_ner("cv", "f.pdf", groups, _profile(years_experience=0.0))
    assert profile.years_experience == 4.0


def test_degree_without_known_degree_uses_span():
    groups = {"Degree": ["PhD in Applied Physics"]}
    profile = profile_from_ner("cv", "f.pdf", groups, _profile())
    assert profile.education == "phd"


def test_dedupe_preserves_order_and_case():
    assert _dedupe(["Flutter", "flutter", "Dart"]) == ["Flutter", "Dart"]
