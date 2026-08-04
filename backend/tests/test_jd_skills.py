from __future__ import annotations

from app.extraction import Profile, extract_profile
from app.extraction._profile import _extract_name, _name_from_filename
from app.jd import _extract_education, structure_jd
from app.ranking import LLMRankingError
from app.ranking._llm import _parse_response
from app.skills import find_skills, skill_like_terms, TECH_SKILLS, SOFT_SKILLS


def test_extract_education_recognizes_full_degree_names():
    assert _extract_education("Bachelor of Science in Computer Science") == "bsc"
    assert _extract_education("Master of Science") == "msc"
    assert _extract_education("Master of Business Administration") == "msc"
    assert _extract_education("Associate Degree in IT") == "diploma"
    assert _extract_education("M.Sc. Comp Sci") == "msc"
    assert _extract_education("no degree mentioned here") is None



def test_alias_matches_canonical_skills():
    assert "postgresql" in find_skills("Works with Postgres", TECH_SKILLS + SOFT_SKILLS)
    assert "javascript" in find_skills("Writes JS", TECH_SKILLS + SOFT_SKILLS)
    assert "typescript" in find_skills("Writes TS", TECH_SKILLS + SOFT_SKILLS)
    assert "kubernetes" in find_skills("Runs k8s", TECH_SKILLS + SOFT_SKILLS)
    assert "machine learning" in find_skills("Applied ML", TECH_SKILLS + SOFT_SKILLS)
    assert "golang" in find_skills("Writes Go", TECH_SKILLS + SOFT_SKILLS)


def test_dotted_skill_names_match():
    assert "next.js" in find_skills("Build UIs with Next.js", TECH_SKILLS + SOFT_SKILLS)
    assert "node.js" in find_skills("Uses Node.js", TECH_SKILLS + SOFT_SKILLS)
    assert "ci/cd" in find_skills("Owns the CI/CD pipeline", TECH_SKILLS + SOFT_SKILLS)


def test_open_vocabulary_terms():
    terms = skill_like_terms("Couchbase, Haskell, distributed systems, Apache Kafka")
    assert "couchbase" in terms
    assert "haskell" in terms
    assert "distributed systems" in terms
    assert "apache kafka" not in terms  # covered by known skill "kafka"


def test_structure_jd_uses_sections_and_open_vocab():
    jd = """Backend Engineer

Requirements
- Go
- Postgres
- Redis
- RabbitMQ
- Docker

Nice to have
- Haskell
- Couchbase
- Kafka
"""
    req = structure_jd(jd)
    assert "golang" in req["required_skills"]
    assert "postgresql" in req["required_skills"]
    assert "redis" in req["required_skills"]
    assert "haskell" in req["preferred_skills"]
    assert "couchbase" in req["preferred_skills"]
    assert "kafka" in req["preferred_skills"]


def test_structure_jd_preferred_falls_back_to_whole_text():
    jd = """Data Engineer with 4+ years experience.
Skills: dbt, Snowflake, Apache Airflow, distributed systems, data pipelines.
"""
    req = structure_jd(jd)
    assert "dbt" in req["required_skills"]
    assert "snowflake" in req["required_skills"]
    assert "distributed systems" in req["required_skills"]
    assert req["min_years"] == 4.0


def test_structure_jd_known_section_jd_unchanged():
    jd = """Senior Backend Engineer

Requirements
- Python
- Docker
- AWS
- PostgreSQL
- 5+ years of experience

Nice to have
- Kubernetes
- Machine Learning

Responsibilities
Design and operate highly available backend services.
"""
    req = structure_jd(jd)
    assert req["required_skills"] == ["python", "postgresql", "docker", "aws"]
    assert req["preferred_skills"] == ["kubernetes", "machine learning"]
    assert req["min_years"] == 5.0


def test_structure_jd_markdown_headers_split_required_vs_preferred():
    jd = """# Junior Flutter Developer Requirements

## Required Qualifications
- Bachelor's degree in Computer Science.
- Experience building mobile applications using Flutter.
- Understanding of state management (Riverpod, Provider, or Bloc).
- Strong problem-solving and communication skills.

## Preferred Qualifications
- Experience with Firebase (Authentication, Firestore).
- Knowledge of local databases (SQLite, Hive, Isar).

## Technical Skills
- Flutter
- Dart
- REST API
- JSON

## Responsibilities
- Develop and maintain Flutter mobile applications.
- Integrate RESTful APIs into mobile applications.
"""
    req = structure_jd(jd)
    assert req["title"] == "Junior Flutter Developer Requirements"
    assert "firebase" not in req["required_skills"]
    assert "sqlite" not in req["required_skills"]
    assert "flutter" in req["required_skills"]
    assert "firebase" in req["preferred_skills"]
    assert "hive" in req["preferred_skills"]


def test_structure_jd_preferred_qualifications_plural_header():
    jd = """Backend Engineer

Required Qualifications
- Python
- PostgreSQL

Preferred Qualifications
- Kubernetes

Nice-to-Have Skills
- Machine Learning
"""
    req = structure_jd(jd)
    assert req["required_skills"] == ["python", "postgresql"]
    assert req["preferred_skills"] == ["kubernetes", "machine learning"]


def test_skill_like_terms_skips_noise_case_insensitively():
    assert skill_like_terms("## Technical Skills, or GetX, Build fast") == []
    assert "or getx" not in skill_like_terms("Riverpod, Provider, Bloc, or GetX")


def test_llm_rank_parse_handles_duplicate_names_by_index():
    candidates = [
        {"candidate_name": "Fathan Azka Pradana", "skills": []},
        {"candidate_name": "Fathan Azka Pradana", "skills": []},
    ]
    content = (
        '{"candidates": ['
        '{"candidate": 2, "rank": 1, "overall": 0.9, "recommendation": "strong_match",'
        ' "explanation": "e2", "strengths": ["s"], "weaknesses": ["w"]},'
        '{"candidate": 1, "rank": 2, "overall": 0.8, "recommendation": "good_match",'
        ' "explanation": "e1", "strengths": [], "weaknesses": []}]}'
    )
    result = _parse_response(content, candidates)
    assert len(result) == 2
    assert result[0].explanation == "e1"
    assert result[1].overall == 0.9


def test_llm_rank_parse_rejects_incomplete_ranking():
    candidates = [
        {"candidate_name": "Alice", "skills": []},
        {"candidate_name": "Bob", "skills": []},
    ]
    content = (
        '{"candidates": [{"candidate": 1, "overall": 0.8, "recommendation": "good_match",'
        ' "explanation": "e", "strengths": [], "weaknesses": []}]}'
    )
    try:
        _parse_response(content, candidates)
        assert False, "expected LLMRankingError"
    except LLMRankingError:
        pass


def test_llm_rank_parse_falls_back_to_unique_name():
    candidates = [{"candidate_name": "Alice Smith", "skills": []}]
    content = (
        '{"candidates": [{"candidate": "Alice Smith", "overall": 0.7,'
        ' "recommendation": "possible_match", "explanation": "e",'
        ' "strengths": [], "weaknesses": []}]}'
    )
    result = _parse_response(content, candidates)
    assert len(result) == 1
    assert result[0].overall == 0.7


def test_extract_name_plain_title_case():
    assert _extract_name("John Doe\nSenior Python Engineer", "john.txt") == "John Doe"


def test_extract_name_skips_section_headers():
    text = "PROFILE SUMMARY\nFULLSTACK & MOBILE DEVELOPER\n10 years experience."
    assert _extract_name(text, "candidate.pdf") == "Candidate"


def test_extract_name_letter_spaced_confirmed_by_filename():
    text = (
        "F A T H A N A Z K A P R A D A N A\n"
        "FULLSTACK & MOBILE DEVELOPER\n"
        "PROFILE SUMMARY\n"
    )
    file_name = "Fathan Azka Pradana_Flutter Developer_LinkedIn Corporate.pdf"
    assert _extract_name(text, file_name) == "Fathan Azka Pradana"
    assert extract_profile(text, file_name).candidate_name == "Fathan Azka Pradana"


def test_extract_name_all_caps_header_area():
    assert _extract_name("JOHN DOE\nPROFILE SUMMARY\n10 years experience.", "cv.txt") == "John Doe"


def test_name_from_filename_strips_role_and_noise():
    assert _name_from_filename("Fathan Azka Pradana_Flutter Developer.pdf") == "Fathan Azka Pradana"
    assert _name_from_filename("john-doe-resume.pdf") == "John Doe"
    assert _name_from_filename("alice.txt") == "Alice"
