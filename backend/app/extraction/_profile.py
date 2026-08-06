from __future__ import annotations

import re
from dataclasses import dataclass

from app.jd import _extract_education
from app.skills import (
    SOFT_SKILLS,
    TECH_SKILLS,
    find_certifications,
    find_skills,
)

EXPERIENCE_RE = re.compile(r"(\d{1,2})\s*\+?\s*(?:years?|yrs?|tahun)", re.I)

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
_PERSON_RE = re.compile(r"^[A-Za-z][A-Za-z''.\-]*(?: [A-Za-z][A-Za-z''.\-]*){1,3}$")
_NAME_SCAN_LINES = 6


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

    @classmethod
    def from_cv(cls, cv: dict) -> Profile:
        return cls(
            candidate_name=cv.get("candidate_name") or "Unknown Candidate",
            skills=cv.get("skills") or [],
            years_experience=cv.get("years_experience") or 0.0,
            education=cv.get("education"),
            certifications=cv.get("certifications") or [],
            profile_text=cv.get("profile_text") or "",
        )


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

        if len(words) >= 4 and all(len(w) == 1 and w.isalpha() for w in words):
            if "".join(words).lower() == fn_compact:
                return fn_name
            continue

        if 2 <= len(words) <= 4 and all(w.istitle() for w in words):
            return " ".join(words)

    for raw in lines[:6]:
        line = raw.strip()
        if not line or _SECTION_HEADERS.match(line) or _ROLE_RE.search(line):
            continue
        words = line.split()
        if 2 <= len(words) <= 4 and all(w.isalpha() and w.isupper() for w in words):
            return " ".join(w.title() for w in words)

    return fn_name or "Unknown Candidate"
