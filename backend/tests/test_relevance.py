from __future__ import annotations

import asyncio

import pytest

from app.config import Settings
from app.extraction import Profile, extract_profile
from app.jd._structure import structure_jd
from app.ranking import (
    MET,
    NOT_MET,
    PARTIALLY_MET,
    PARTIALLY_RELEVANT,
    RELEVANT,
    UNRELATED,
    RankingService,
    evaluate_relevance,
)
from tests.conftest import create_job, upload_cvs_and_wait

FLUTTER_JD = """Flutter Developer

Requirements
- Flutter
- Dart
- Mobile development
- REST API
- State management

Responsibilities
Build and maintain Flutter mobile applications.
"""

FLUTTER_CV = """Rani Pratama
Flutter Developer

Summary
3 years building Flutter mobile applications.

Skills
Flutter, Dart, REST API, State management, Mobile development, Git

Experience
Flutter Developer at PT Maju, built and shipped Flutter mobile apps.
"""

REACT_NATIVE_CV = """Bob Santoso
React Native Developer

Summary
4 years building React Native mobile apps.

Skills
React Native, JavaScript, REST API, Redux, Git

Experience
React Native Developer at PT Karya, built mobile applications.
"""

BACKEND_CV = """Alice Wijaya
Backend Developer

Summary
5 years building backend services.

Skills
Python, Django, PostgreSQL, Docker, AWS, REST API, Git

Experience
Backend Developer at PT Data, built REST APIs and microservices.
"""

ACCOUNTANT_CV = """Mr Accountant
Senior Accountant

Summary
8 years of accounting and taxation experience.

Skills
Excel, Financial reporting, Auditing, Taxation, QuickBooks

Experience
Senior Accountant at PT Akuntan, responsible for financial reporting,
auditing, and taxation.
"""

ACCOUNTANT_10Y_CV = """Mr Big Accountant
Senior Accountant

Summary
10 years of accounting and taxation experience.

Skills
Excel, Financial reporting, Auditing, Taxation, QuickBooks, Accounting

Experience
Senior Accountant at PT Akuntan Besar, responsible for financial reporting,
auditing, and taxation for 10 years.
"""

GRAPHIC_DESIGNER_CV = """Dina Lestari
Graphic Designer

Summary
6 years of graphic design experience.

Skills
Photoshop, Illustrator, Figma, Branding, UI/UX Design

Experience
Graphic Designer at Studio Kreatif, designed branding and marketing materials.
"""

HR_MANAGER_CV = """Hana Putri
HR Manager

Summary
9 years of human resources management.

Skills
Recruiting, Onboarding, Payroll, Communication, Leadership

Experience
HR Manager at PT Sumber Daya, managed recruitment, onboarding, and payroll.
"""


def _requirements() -> dict:
    return structure_jd(FLUTTER_JD)


def _profile(cv_text: str, name: str) -> Profile:
    return extract_profile(cv_text, name)


# ---------------------------------------------------------------- unit tests

@pytest.mark.parametrize(
    "cv_text,name,expected",
    [
        (FLUTTER_CV, "rani.txt", RELEVANT),
        (REACT_NATIVE_CV, "bob.txt", RELEVANT),
        (BACKEND_CV, "alice.txt", PARTIALLY_RELEVANT),
        (ACCOUNTANT_CV, "acct.txt", UNRELATED),
        (ACCOUNTANT_10Y_CV, "acct10.txt", UNRELATED),
        (GRAPHIC_DESIGNER_CV, "dina.txt", UNRELATED),
        (HR_MANAGER_CV, "hana.txt", UNRELATED),
    ],
)
def test_relevance_gate_classifies_professional_background(cv_text, name, expected):
    result = evaluate_relevance(_profile(cv_text, name), _requirements())
    assert result["relevance"] == expected


def test_flutter_developer_is_met():
    result = evaluate_relevance(_profile(FLUTTER_CV, "rani.txt"), _requirements())
    assert result["classification"] == MET
    assert result["meets_job_description"] is True
    assert result["relevance_score"] > 0


def test_accountant_is_not_met_with_zero_relevance():
    result = evaluate_relevance(_profile(ACCOUNTANT_CV, "acct.txt"), _requirements())
    assert result["classification"] == NOT_MET
    assert result["meets_job_description"] is False
    assert result["relevance_score"] == 0.0
    assert "not relevant" in result["reason"].lower()


def test_generic_soft_skill_words_do_not_make_candidate_relevant():
    # A CV full of generic words must not be treated as relevant.
    generic = """Pat Doe
    Project Manager

    Summary
    7 years leading cross-functional teams with strong communication skills.

    Skills
    Communication, Leadership, Teamwork, Management, Problem Solving, Planning

    Experience
    Managed many projects and coordinated team communication.
    """
    result = evaluate_relevance(_profile(generic, "pat.txt"), _requirements())
    assert result["classification"] == NOT_MET
    assert result["relevance_score"] == 0.0


def test_unrelated_candidate_never_enters_scoring():
    """The relevance gate is a hard stop: score_profile must not run at all."""
    import app.ranking._service as service_module

    original = service_module.score_profile

    def boom(*args, **kwargs):
        raise AssertionError("score_profile must not be called for an UNRELATED candidate")

    service_module.score_profile = boom
    settings = Settings()
    service = RankingService(settings)
    req = _requirements()
    profile = _profile(ACCOUNTANT_CV, "acct.txt")
    cv = {
        "id": "cv-1",
        "job_id": "job-1",
        "candidate_name": "Mr Accountant",
        "skills": profile.skills,
    }
    try:
        ranked, source = asyncio.run(service.rank(req, [profile], [cv]))
    finally:
        service_module.score_profile = original

    assert source == "rules"
    entry = ranked[0]
    assert entry["classification"] == NOT_MET
    assert entry["overall_score"] == 0.0
    assert entry["meets_job_description"] is False
    # No skill/experience/education scoring artifacts.
    assert entry["skill_score"] == 0.0
    assert entry["experience_score"] == 0.0
    assert entry["education_score"] == 0.0
    assert entry["certification_score"] == 0.0


def test_not_met_candidate_ranks_below_met_candidate():
    """NOT_MET must be forced to the bottom even when scores are equal."""
    settings = Settings()
    service = RankingService(settings)
    req = _requirements()
    flutter = _profile(FLUTTER_CV, "rani.txt")
    acct = _profile(ACCOUNTANT_CV, "acct.txt")
    cvs = [
        {"id": "cv-flutter", "candidate_name": "Rani Pratama", "skills": flutter.skills},
        {"id": "cv-acct", "candidate_name": "Mr Accountant", "skills": acct.skills},
    ]
    ranked, _ = asyncio.run(service.rank(req, [flutter, acct], cvs))
    assert ranked[0]["id"] == "cv-flutter"
    assert ranked[0]["classification"] == MET
    assert ranked[0]["overall_score"] > 0
    assert ranked[1]["id"] == "cv-acct"
    assert ranked[1]["classification"] == NOT_MET
    assert ranked[1]["overall_score"] == 0.0


# ------------------------------------------------------------- API-level tests

def test_rank_unrelated_cvs_not_met_score_zero_and_bottom(client, cv_builder):
    job_id = create_job(client, title="Flutter Developer", description=FLUTTER_JD)
    upload_cvs_and_wait(
        client,
        job_id,
        cv_builder,
        ("rani.txt", FLUTTER_CV),
        ("bob.txt", REACT_NATIVE_CV),
        ("alice.txt", BACKEND_CV),
        ("acct.txt", ACCOUNTANT_CV),
        ("dina.txt", GRAPHIC_DESIGNER_CV),
        ("hana.txt", HR_MANAGER_CV),
    )

    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 200, resp.text
    results = resp.json()["results"]
    assert len(results) == 6

    by_name = {r["candidate_name"]: r for r in results}
    assert by_name["Rani Pratama"]["classification"] == MET
    assert by_name["Bob Santoso"]["classification"] in (MET, PARTIALLY_MET)
    assert by_name["Alice Wijaya"]["classification"] == PARTIALLY_MET

    for name in ("Mr Accountant", "Dina Lestari", "Hana Putri"):
        assert by_name[name]["classification"] == NOT_MET
        assert by_name[name]["meets_job_description"] is False
        assert by_name[name]["overall_score"] == 0
        assert by_name[name]["skill_score"] == 0
        assert by_name[name]["experience_score"] == 0
        assert by_name[name]["education_score"] == 0
        assert by_name[name]["certification_score"] == 0

    # NOT_MET candidates are always at the bottom of the ranking.
    assert results[0]["candidate_name"] == "Rani Pratama"
    assert [r["classification"] for r in results[-3:]] == [NOT_MET, NOT_MET, NOT_MET]
    assert {r["candidate_name"] for r in results[-3:]} == {
        "Mr Accountant",
        "Dina Lestari",
        "Hana Putri",
    }
    # Non-zero scores only exist above the NOT_MET tail.
    assert all(r["overall_score"] > 0 for r in results[:3])


def test_high_experience_unrelated_cv_cannot_outrank_relevant_cv(client, cv_builder):
    """10 years of unrelated experience must never yield a normal score or rank."""
    job_id = create_job(client, title="Flutter Developer", description=FLUTTER_JD)
    upload_cvs_and_wait(
        client,
        job_id,
        cv_builder,
        ("rani.txt", FLUTTER_CV),
        ("acct10.txt", ACCOUNTANT_10Y_CV),
    )

    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 200, resp.text
    results = resp.json()["results"]

    assert results[0]["candidate_name"] == "Rani Pratama"
    assert results[0]["classification"] == MET
    assert results[0]["overall_score"] > 0

    assert results[1]["candidate_name"] == "Mr Big Accountant"
    assert results[1]["classification"] == NOT_MET
    assert results[1]["overall_score"] == 0
    assert results[1]["rank"] == 2  # still bottom of the list

    # Persisted rankings agree with the rank response.
    persisted = client.get(f"/api/jobs/{job_id}/rankings").json()["results"]
    assert persisted[0]["candidate_name"] == "Rani Pratama"
    assert persisted[1]["candidate_name"] == "Mr Big Accountant"
    assert persisted[1]["overall_score"] == 0
    assert persisted[1]["classification"] == NOT_MET