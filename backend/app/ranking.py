from __future__ import annotations

import re
from dataclasses import dataclass

from app.config import Settings
from app.jd import _extract_education
from app.skills import (
    CERT_KEYWORDS,
    SOFT_SKILLS,
    TECH_SKILLS,
    find_certifications,
    find_skills,
)

EDUCATION_LEVELS = {"": 0, "diploma": 1, "bsc": 2, "msc": 3, "phd": 4}
EXPERIENCE_RE = re.compile(r"(\d{1,2})\s*\+?\s*(?:years?|yrs?|tahun)", re.I)
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


@dataclass
class Profile:
    candidate_name: str
    skills: list[str]
    years_experience: float
    education: str | None
    certifications: list[str]
    profile_text: str

    def as_dict(self) -> dict:
        return {
            "candidate_name": self.candidate_name,
            "skills": self.skills,
            "years_experience": self.years_experience,
            "education": self.education,
            "certifications": self.certifications,
        }


def extract_profile(text: str, file_name: str = "") -> Profile:
    skills = find_skills(text, TECH_SKILLS + SOFT_SKILLS)
    m = EXPERIENCE_RE.search(text)
    years = float(m.group(1)) if m else 0.0
    return Profile(
        candidate_name=_extract_name(text, file_name),
        skills=skills,
        years_experience=years,
        education=_extract_education(text),
        certifications=find_certifications(text),
        profile_text=text,
    )


_SECTION_HEADERS = re.compile(
    r"^(profile|summary|education|experience|skills?|projects?|languages?|contact|"
    r"objective|about|work|employment|professional|personal|technical|interest|"
    r"certifications?|achievements?|awards?|references?|qualifications?|strengths?|"
    r"riwayat|pendidikan|pengalaman|kemampuan|keahlian)\b",
    re.I,
)
_ROLE_WORDS = re.compile(
    r"^(developer|engineer|designer|consultant|manager|analyst|architect|"
    r"lead|intern|specialist|director|head|officer|founder|recruiter|"
    r"mobile|flutter|frontend|backend|fullstack|software|web|graphic|devops|"
    r"ui|ux|data|tech|staff|senior|junior|principal)$",
    re.I,
)
_ROLE_RE = re.compile(
    r"\b(developer|engineer|designer|consultant|manager|analyst|architect|"
    r"lead|intern|specialist|director|head|officer|founder|recruiter|student)\b",
    re.I,
)
_PERSON_RE = re.compile(r"^[A-Za-z][A-Za-z'’.\-]*(?: [A-Za-z][A-Za-z'’.\-]*){1,3}$")
_NAME_SCAN_LINES = 6


def _name_from_filename(file_name: str) -> str:
    stem = re.sub(r"\.(pdf|docx|doc|txt)$", "", file_name, flags=re.I)
    first = stem.split("_", maxsplit=1)[0]
    noise = re.compile(
        r"^(cv|resume|résumé|curriculum vitae|linkedin|updated|new|final|copy)$", re.I
    )
    words = [
        w
        for w in re.split(r"[\s\-–—]+", first.strip())
        if w and not noise.match(w) and not _ROLE_WORDS.match(w)
    ]
    if words:
        return " ".join(w.title() for w in words)
    return stem.replace("_", " ").replace("-", " ").strip().title()


def _extract_name(text: str, file_name: str) -> str:
    fn_name = _name_from_filename(file_name)
    fn_compact = re.sub(r"\s+", "", fn_name.lower())

    # A full person name in the filename ("First Last", confirmed in the text)
    # is the most reliable signal — e.g. "RANGGA DWI SAPUTRA" in the header.
    if fn_compact and _PERSON_RE.match(fn_name) and fn_compact in re.sub(
        r"\s+", "", text.lower()
    ):
        return fn_name

    lines = text.splitlines()
    for raw in lines[:_NAME_SCAN_LINES]:
        line = raw.strip()
        if not line or _SECTION_HEADERS.match(line) or _ROLE_RE.search(line):
            continue
        words = line.split()

        # letter-spaced name, e.g. "F A T H A N A Z K A P R A D A N A" (LinkedIn
        # exports). Confirm against the filename before accepting it.
        if len(words) >= 4 and all(len(w) == 1 and w.isalpha() for w in words):
            if "".join(words).lower() == fn_compact:
                return fn_name
            continue

        # name line: 2-4 Title Case words (headers are usually ALL CAPS)
        if 2 <= len(words) <= 4 and all(w.istitle() for w in words):
            return " ".join(words)

    # secondary pass: all-caps name (e.g. "JOHN DOE") in the header area only
    for raw in lines[:6]:
        line = raw.strip()
        if not line or _SECTION_HEADERS.match(line) or _ROLE_RE.search(line):
            continue
        words = line.split()
        if 2 <= len(words) <= 4 and all(w.isalpha() and w.isupper() for w in words):
            return " ".join(w.title() for w in words)

    return fn_name or "Unknown Candidate"


def score_profile(profile: Profile, requirements: dict, settings: Settings) -> dict:
    req_skills = requirements.get("required_skills") or []
    pref_skills = requirements.get("preferred_skills") or []
    min_years = float(requirements.get("min_years") or 0.0)
    req_edu = requirements.get("education")
    req_certs = requirements.get("certifications") or []

    matched_req = [s for s in req_skills if s in profile.skills]
    matched_pref = [s for s in pref_skills if s in profile.skills]
    matched_certs = [c for c in req_certs if c in profile.certifications]

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
