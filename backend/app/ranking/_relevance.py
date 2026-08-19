from __future__ import annotations

import re

from app.extraction import Profile
from app.ranking._requirements import Requirements
from app.skills import SOFT_SKILLS

# Relevance verdicts for the hard gate.
RELEVANT = "RELEVANT"
PARTIALLY_RELEVANT = "PARTIALLY_RELEVANT"
UNRELATED = "UNRELATED"

# Classification exposed on ranked candidates.
MET = "MET"
PARTIALLY_MET = "PARTIALLY_MET"
NOT_MET = "NOT_MET"

_CLASSIFICATION = {
    RELEVANT: MET,
    PARTIALLY_RELEVANT: PARTIALLY_MET,
    UNRELATED: NOT_MET,
}
_MEETS_JOB_DESCRIPTION = {
    RELEVANT: True,
    PARTIALLY_RELEVANT: False,
    UNRELATED: False,
}

_WORD_SPLIT = re.compile(r"[\W_]+")

# Domain keyword sets used to decide whether a candidate's professional
# background overlaps the job. Generic words (management, communication, team,
# project, technology, ...) are deliberately NOT signals here.
_DOMAIN_TERMS: dict[str, set[str]] = {
    "mobile": {
        "flutter",
        "dart",
        "react native",
        "android",
        "ios",
        "kotlin",
        "swift",
        "xcode",
        "mobile development",
        "mobile app",
        "mobile apps",
        "mobile developer",
        "mobile engineer",
    },
    "frontend": {
        "frontend",
        "front-end",
        "react",
        "angular",
        "vue",
        "next js",
        "html",
        "css",
        "typescript",
        "javascript",
        "tailwind",
        "redux",
        "web developer",
        "web development",
        "ui developer",
    },
    "backend": {
        "backend",
        "back-end",
        "server-side",
        "microservices",
        "python",
        "java",
        "golang",
        "node js",
        "nodejs",
        "django",
        "fastapi",
        "spring boot",
        "spring",
        "sql",
        "postgresql",
        "mysql",
        "backend developer",
        "backend engineer",
    },
    "data": {
        "data scientist",
        "data engineer",
        "data analyst",
        "analytics",
        "etl",
        "pandas",
        "spark",
        "machine learning",
        "data pipeline",
        "data pipelines",
        "data science",
        "power bi",
        "tableau",
    },
    "devops": {
        "devops",
        "docker",
        "kubernetes",
        "ci cd",
        "terraform",
        "aws",
        "azure",
        "gcp",
        "cloud",
        "jenkins",
        "site reliability",
        "sre",
    },
    "qa": {
        "qa",
        "quality assurance",
        "test automation",
        "selenium",
        "cypress",
        "pytest",
        "junit",
        "jest",
        "test engineer",
        "test analyst",
    },
    "software": {
        "developer",
        "engineer",
        "programmer",
        "software development",
        "software developer",
        "software engineer",
        "fullstack",
        "full-stack",
        "coding",
        "programming",
        "application development",
    },
    "design": {
        "graphic design",
        "graphic designer",
        "designer",
        "photoshop",
        "illustrator",
        "indesign",
        "branding",
        "visual design",
        "ui/ux",
        "ui ux",
        "ux design",
        "ui design",
        "art direction",
        "creative",
    },
    "finance": {
        "accountant",
        "accounting",
        "tax",
        "taxation",
        "audit",
        "auditing",
        "financial",
        "finance",
        "bookkeeping",
        "cpa",
        "cfa",
        "payroll",
        "treasury",
        "financial reporting",
        "controller",
        "actuary",
    },
    "hr": {
        "human resources",
        "hr manager",
        "recruiter",
        "recruiting",
        "hiring",
        "talent acquisition",
        "onboarding",
        "employee relations",
        "people operations",
        "hr",
        "compensation",
    },
    "marketing": {
        "marketing",
        "seo",
        "sem",
        "content marketing",
        "social media",
        "brand manager",
        "campaign",
        "advertising",
        "growth marketing",
        "digital marketing",
    },
    "sales": {
        "sales",
        "business development",
        "account executive",
        "account manager",
        "revenue",
        "sales manager",
    },
    "legal": {
        "legal",
        "lawyer",
        "attorney",
        "compliance",
        "paralegal",
        "contracts",
        "corporate law",
        "counsel",
    },
    "customer_support": {
        "customer support",
        "customer service",
        "help desk",
        "support engineer",
        "technical support",
        "support specialist",
    },
    "operations": {
        "operations",
        "office manager",
        "administrative",
        "operations manager",
        "project manager",
        "operations coordinator",
    },
}

def _normalize(value: str) -> str:
    return _WORD_SPLIT.sub(" ", value.lower()).strip()


_NORMALIZED_TERMS: dict[str, list[str]] = {
    domain: [_normalize(term) for term in terms]
    for domain, terms in _DOMAIN_TERMS.items()
}


def _domains_of(text: str) -> set[str]:
    """Return the professional domains whose signals appear in ``text``."""
    if not text:
        return set()
    low = " " + _normalize(text) + " "
    found: set[str] = set()
    for domain, terms in _NORMALIZED_TERMS.items():
        for term in terms:
            if f" {term} " in low:
                found.add(domain)
                break
    return found


def _job_text(requirements: dict) -> str:
    parts = [
        requirements.get("title") or "",
        " ".join(requirements.get("required_skills") or []),
        " ".join(requirements.get("preferred_skills") or []),
        " ".join(requirements.get("responsibilities") or []),
    ]
    return " ".join(part for part in parts if part)


def _candidate_text(profile: Profile) -> str:
    return " ".join(
        part
        for part in (
            " ".join(profile.skills),
            profile.profile_text or "",
        )
        if part
    )


def _result(
    relevance: str,
    relevance_score: float,
    reason: str,
) -> dict:
    return {
        "relevance": relevance,
        "classification": _CLASSIFICATION[relevance],
        "meets_job_description": _MEETS_JOB_DESCRIPTION[relevance],
        "relevance_score": round(relevance_score, 3),
        "reason": reason,
    }


def _reason(relevance: str, matched_specific: list[str], job_domains: set[str], cand_domains: set[str]) -> str:
    if relevance == UNRELATED:
        return "Candidate's professional background is not relevant to this job."
    parts: list[str] = []
    if matched_specific:
        parts.append(f"matches required skill(s): {', '.join(matched_specific[:4])}")
    shared = (job_domains - {"software"}) & cand_domains
    if shared:
        parts.append(f"shares the {'/'.join(sorted(shared))} professional domain")
    if not parts:
        parts.append("related software/engineering background")
    label = "Partially relevant" if relevance == PARTIALLY_RELEVANT else "Relevant"
    return f"{label} — " + ", ".join(parts) + "."


def evaluate_relevance(profile: Profile, requirements: dict) -> dict:
    """Classify how relevant a candidate's professional background is to a job.

    This is a HARD gate, not a scoring weight. ``UNRELATED`` means the candidate
    must not proceed to any scoring/ranking logic.
    """
    req = Requirements(requirements=requirements)
    job_text = _job_text(requirements)
    job_domains = _domains_of(job_text) if job_text.strip() else set()

    if not job_domains and not req.req_skills:
        return _result(
            RELEVANT,
            0.5,
            "Job description provides no extractable requirements; relevance could not be assessed.",
        )

    cand_skills = {s.lower() for s in profile.skills}
    soft = {s.lower() for s in SOFT_SKILLS}
    matched_specific = [
        s
        for s in req.req_skills
        if s.lower() in cand_skills and s.lower() not in soft
    ]

    cand_domains = _domains_of(_candidate_text(profile))
    specific_shared = (job_domains - {"software"}) & cand_domains
    software_shared = "software" in job_domains and "software" in cand_domains

    n_specific = len(matched_specific)
    if n_specific >= 2:
        verdict = RELEVANT
    elif n_specific == 1:
        verdict = RELEVANT if specific_shared else PARTIALLY_RELEVANT
    elif specific_shared:
        verdict = RELEVANT
    elif software_shared:
        verdict = PARTIALLY_RELEVANT
    else:
        verdict = UNRELATED

    ratio = n_specific / len(req.req_skills) if req.req_skills else 0.0
    domain_score = 1.0 if specific_shared else (0.5 if software_shared else 0.0)
    relevance_score = 0.6 * ratio + 0.4 * domain_score

    return _result(
        verdict,
        relevance_score,
        _reason(verdict, matched_specific, job_domains, cand_domains),
    )
