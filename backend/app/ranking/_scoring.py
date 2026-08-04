from __future__ import annotations

from app.config import Settings
from app.extraction import Profile

EDUCATION_LEVELS = {"": 0, "diploma": 1, "bsc": 2, "msc": 3, "phd": 4}
RECOMMENDATIONS = {
    "strong_match": "Strong match — prioritize for interview",
    "good_match": "Good match — worth interviewing",
    "possible_match": "Possible match — consider depending on needs",
    "weak_match": "Weak match — low priority",
}
BUCKET_RANGES = [
    (0.85, "strong_match"),
    (0.70, "good_match"),
    (0.50, "possible_match"),
    (0.00, "weak_match"),
]


def score_profile(profile: Profile, requirements: dict, settings: Settings) -> dict:
    req_skills = requirements.get("required_skills") or []
    pref_skills = requirements.get("preferred_skills") or []
    min_years = float(requirements.get("min_years") or 0.0)
    req_edu = requirements.get("education")
    req_certs = requirements.get("certifications") or []

    # Case-insensitive matching: canonical skills are lowercase; LLM skills may be capitalized.
    profile_skills = {s.lower() for s in profile.skills}
    profile_certs = {c.lower() for c in profile.certifications}

    matched_req = [s for s in req_skills if s.lower() in profile_skills]
    matched_pref = [s for s in pref_skills if s.lower() in profile_skills]
    matched_certs = [c for c in req_certs if c.lower() in profile_certs]

    if req_skills:
        skill_score = 0.7 * (len(matched_req) / len(req_skills)) + 0.3 * (
            len(matched_pref) / len(pref_skills) if pref_skills else 0.0
        )
    elif pref_skills:
        skill_score = 0.5 + 0.5 * (len(matched_pref) / len(pref_skills))
    else:
        skill_score = 0.5 if profile.skills else 0.2

    if min_years > 0:
        experience_score = min(1.0, profile.years_experience / min_years)
    else:
        experience_score = 0.7 if profile.years_experience > 0 else 0.4

    if req_edu:
        requirement_level = EDUCATION_LEVELS.get(req_edu, 0)
        education_score = min(
            1.0, EDUCATION_LEVELS.get(profile.education or "", 0) / max(1, requirement_level)
        )
    else:
        education_score = 0.8 if profile.education else 0.5

    if req_certs:
        certification_score = len(matched_certs) / len(req_certs)
    else:
        certification_score = 0.7 if profile.certifications else 0.5

    weights = {
        "skill": settings.w_skill,
        "experience": settings.w_experience,
        "education": settings.w_education,
        "certification": settings.w_certification,
    }
    total_w = sum(weights.values()) or 1.0
    overall = (
        skill_score * weights["skill"]
        + experience_score * weights["experience"]
        + education_score * weights["education"]
        + certification_score * weights["certification"]
    ) / total_w
    overall = max(0.0, min(1.0, overall))

    return {
        "skill_score": round(skill_score, 3),
        "experience_score": round(experience_score, 3),
        "education_score": round(education_score, 3),
        "certification_score": round(certification_score, 3),
        "overall": round(overall, 3),
        "matched_required": matched_req,
        "matched_preferred": matched_pref,
        "missing_required": [s for s in req_skills if s not in profile.skills],
        "matched_certs": matched_certs,
    }


def bucket_for(overall: float) -> str:
    for threshold, bucket in BUCKET_RANGES:
        if overall >= threshold:
            return bucket
    return "weak_match"


def rule_reasoning(profile: Profile, requirements: dict, scores: dict) -> dict:
    gaps = scores["missing_required"]
    strengths = [
        f"Matches required skill: {skill}" for skill in scores["matched_required"][:6]
    ]
    if scores["matched_preferred"]:
        strengths.append(
            f"Has preferred skill: {scores['matched_preferred'][0]}"
        )
    if requirements.get("min_years"):
        meets = profile.years_experience >= float(requirements["min_years"])
        strengths.append(
            f"{profile.years_experience:.0f} years of experience "
            f"({'meets' if meets else 'does not yet meet'} the "
            f"{float(requirements['min_years']):.0f}-year minimum)"
        )
    weaknesses = []
    for skill in gaps[:6]:
        weaknesses.append(f"Missing required skill: {skill}")
    if requirements.get("education") and profile.education not in (
        None,
        requirements.get("education"),
    ):
        weaknesses.append(
            f"Education ({profile.education or 'not stated'}) is below the "
            f"required level ({requirements['education']})"
        )
    if not strengths and not weaknesses:
        strengths.append("Generic skill set")
        weaknesses.append("No clear evidence of required experience")

    bucket = bucket_for(scores["overall"])
    explanation = (
        f"{profile.candidate_name} matches {len(scores['matched_required'])} of "
        f"{len(requirements.get('required_skills') or [])} required skills"
        f"{(' (' + ', '.join(scores['matched_required'][:5]) + ')') if scores['matched_required'] else ''}."
    )
    if gaps:
        explanation += f" Missing: {', '.join(gaps[:4])}."
    if requirements.get("min_years"):
        explanation += (
            f" Experience: {profile.years_experience:.0f} of "
            f"{float(requirements['min_years']):.0f} required years."
        )
    explanation += f" Recommendation: {RECOMMENDATIONS[bucket]}"

    return {
        "recommendation": bucket,
        "explanation": explanation,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "skill_gaps": gaps,
    }
