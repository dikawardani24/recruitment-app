from __future__ import annotations

from app.config import Settings
from app.extraction import Profile
from app.ranking._profile_score_counter import ProfileScoreCounter
from app.ranking._requirements import Requirements

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


def score_profile(profile: Profile, req_dict: dict, settings: Settings) -> dict:
    requirements = Requirements(requirements=req_dict)
    score = ProfileScoreCounter(profile=profile, requirements=requirements, settings=settings).count()
    
    skill_score = score.skill_score
    experience_score = score.experience_score
    education_score = score.edu_score
    certification_score = score.cert_score
  
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
        "matched_required": requirements.matched_req(profile),
        "matched_preferred": requirements.matched_pref(profile),
        "missing_required": requirements.missing_skill(profile),
        "matched_certs": requirements.matched_certs(profile),
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
