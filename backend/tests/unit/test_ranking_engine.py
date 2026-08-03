from __future__ import annotations

from uuid import uuid4

from app.application.ranking.ranking_engine import RankingEngine, SearchIntent
from app.core.config import RankingWeights
from app.domain.entities import Candidate, CandidateProfile, Education, Experience, Project, VectorHit
from app.domain.services import YearsExperienceCalculator


def _candidate(
    skills: list[str],
    years: float,
    certs: list[str] | None = None,
    responsibilities: list[str] | None = None,
    projects: list | None = None,
    education: list | None = None,
) -> Candidate:
    return Candidate(
        id=uuid4(),
        name="Jane Doe",
        email=None,
        phone=None,
        location="Berlin",
        summary="Flutter engineer",
        profile=CandidateProfile(
            candidate={"name": "Jane Doe"},
            summary="Flutter engineer",
            skills=skills,
            experience=[
                Experience(
                    company="BankCo",
                    position="Senior Flutter Engineer",
                    start_date="2018-01",
                    end_date=None,
                    responsibilities=responsibilities or ["Led squad"],
                )
            ],
            certifications=certs or [],
            projects=projects or [],
            education=education or [],
        ),
        derived_metrics={"years_experience": years, "skill_count": len(skills)},
    )


def _hits(section: str = "experience", score: float = 0.9) -> list[VectorHit]:
    from app.core.enums import Section

    return [
        VectorHit(
            chunk_id=uuid4(),
            candidate_id=uuid4(),
            candidate_name="Jane Doe",
            resume_id=uuid4(),
            section=Section(section),
            text="Led mobile payments at BankCo",
            score=score,
        )
    ]


def _engine() -> RankingEngine:
    return RankingEngine(RankingWeights(), YearsExperienceCalculator())


def test_best_bucket_for_strong_match():
    engine = _engine()
    intent = SearchIntent(
        required_skills=["Flutter", "Dart"],
        nice_to_have_skills=["Firebase"],
        min_years=3,
        domain="banking",
        certifications_required=["AWS Certified Developer"],
    )
    candidate = _candidate(
        skills=["flutter", "dart", "firebase", "go", "graphql", "rest apis"],
        years=7.0,
        certs=["AWS Certified Developer – Associate"],
        responsibilities=["Led mobile payments squad of 4 engineers", "Architected CI/CD"],
        projects=[Project(name="openbank-sdk", url="https://github.com/jane/x", highlights=["700 stars"], description="SDK")],
        education=[Education(institution="TU Berlin", degree="BSc", field="CS", start_year=2012, end_year=2016)],
    )
    scores = engine.compute_tier1(candidate, intent, _hits())
    assert scores.skill_coverage == 1.0
    assert scores.certification == 1.0
    assert engine.assign_bucket(scores) == "best"


def test_alternative_bucket_for_weak_match():
    engine = _engine()
    intent = SearchIntent(required_skills=["Kubernetes", "Terraform"], min_years=5, domain="devops")
    candidate = _candidate(["flutter"], 1.0)
    scores = engine.compute_tier1(candidate, intent, _hits(score=0.2))
    assert engine.assign_bucket(scores) == "alternative"


def test_hidden_gem_bucket_despite_low_years():
    engine = _engine()
    intent = SearchIntent(required_skills=["Flutter"], min_years=8, domain="banking")
    candidate = _candidate(
        skills=["flutter", "dart", "go", "graphql", "firebase", "kubernetes"],
        years=2.0,
        responsibilities=["Led mobile squad", "Architected payments system"],
        projects=[Project(name="payments-lib", url="https://github.com/jane/payments", highlights=["50k downloads"], description="OSS payments lib")],
    )
    scores = engine.compute_tier1(candidate, intent, _hits(score=0.3))
    bucket = engine.assign_bucket(scores)
    assert bucket == "hidden_gem"
    assert scores.hidden_gem >= 0.5
