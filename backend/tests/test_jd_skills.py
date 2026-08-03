from __future__ import annotations

from app.jd import structure_jd
from app.skills import find_skills, skill_like_terms, TECH_SKILLS, SOFT_SKILLS


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
