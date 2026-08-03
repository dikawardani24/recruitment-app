from __future__ import annotations

import re

from app.skills import (
    SOFT_SKILLS,
    TECH_SKILLS,
    find_certifications,
    find_skills,
    skill_like_terms,
)

_YEARS_RE = re.compile(r"(\d+)\s*\+?\s*(?:to\s*\d+\s*\+?\s*)?(?:years?|yrs?|tahun)\b", re.I)
_SENIORITY = re.compile(
    r"\b(senior|junior|mid[- ]level|lead|principal|staff|entry[- ]level|intern)\b", re.I
)
_EMPLOYMENT = re.compile(
    r"\b(full[- ]time|part[- ]time|contract|freelance|internship|remote|hybrid|on[- ]site)\b",
    re.I,
)
_EDUCATION_RE = re.compile(
    r"\b(bachelor['’]?s?|b\.?s\.?c?|b\.?a\.?|b\.?eng\.?|b\.?tech\.?|"
    r"master['’]?s?|m\.?s\.?c?|m\.?b\.?a\.?|m\.?a\.?|m\.?eng\.?|m\.?tech\.?|"
    r"ph\.?d|doctorate|sarjana|magister|doktor|s1|s2|s3|minimal\s+d3|diploma|"
    r"associate['’]?s?\s+degree|associate)\b",
    re.I,
)

_MD_HEADER = re.compile(r"^#+\s*")
_HEADER_TRAILER = r"(?:\s+(?:qualifications?|skills?|requirements?))?\s*:?\s*$"

_REQUIRED_SECTION = re.compile(
    r"^(requirements|must have|must-have|minimum qualifications?|qualifications?|"
    r"required|key requirements|skills required|what you['’]?ll need|"
    r"kualifikasi|persyaratan|syarat)" + _HEADER_TRAILER,
    re.I,
)
_PREFERRED_SECTION = re.compile(
    r"^(nice[- ]to[- ]have|preferred|bonus|pluses|good to have|diutamakan|nilai tambah)"
    + _HEADER_TRAILER,
    re.I,
)
_RESPONSIBILITIES_SECTION = re.compile(
    r"^(responsibilities|what you['’]?ll do|role\s*&\s*responsibilities|job\s+description|"
    r"about the role|duties|tugas|tanggung\s+jawab|deskripsi\s+pekerjaan|about the job)"
    + _HEADER_TRAILER,
    re.I,
)
_TITLE_SECTION = re.compile(r"^(job\s+title|position|role|posisi)\s*:?\s*$", re.I)
_SECTION_HEADER = re.compile(
    r"^(?:#+\s*)?(requirements|must have|qualifications|nice to have|preferred|"
    r"responsibilities|technical|soft|about|company|job description|skills|benefits|"
    r"what you|experience|education|summary)",
    re.I,
)
_DATE_ONLY = re.compile(r"^[\s\d/.\-–—]*$")


def _normalize_header(line: str) -> str:
    """Strip markdown heading prefix and trailing colon from a section header."""
    return _MD_HEADER.sub("", line).strip().rstrip(":").strip()


def structure_jd(text: str) -> dict | None:
    """Rule-based Job Description → structured requirements dict."""
    if not text or not text.strip():
        return None
    sections = _detect_sections(text)
    lines = text.splitlines()
    blocks: dict[str, list[str]] = {}
    for s in sections:
        block = "\n".join(lines[s["start"] + 1 : s["end"]]).strip()
        blocks.setdefault(s["name"], []).append(block)
    req_block = "\n".join(blocks.get("required", [])).strip()
    pref_block = "\n".join(blocks.get("preferred", [])).strip()
    resp_block = "\n".join(blocks.get("responsibilities", [])).strip()

    req_text = req_block or text
    required_skills = _jd_skills(req_text)

    pref_text = pref_block or _text_without_sections(text, sections, {"required"})
    preferred_skills = [s for s in _jd_skills(pref_text) if s not in required_skills]

    m = _YEARS_RE.search(text)
    return {
        "title": _extract_title(text, sections),
        "industry": _extract_industry(text),
        "employment_type": _first(_EMPLOYMENT, text),
        "seniority": _first(_SENIORITY, text),
        "required_skills": required_skills,
        "preferred_skills": preferred_skills,
        "min_years": float(m.group(1)) if m else 0.0,
        "education": _extract_education(text),
        "certifications": find_certifications(text),
        "responsibilities": _extract_responsibilities(resp_block or text),
    }


def _jd_skills(text: str) -> list[str]:
    """Skills from JD text: dictionary matches (with aliases) + open-vocabulary terms."""
    known = find_skills(text, TECH_SKILLS + SOFT_SKILLS)
    known_set = set(known)
    extras = [t for t in skill_like_terms(text) if t not in known_set]
    return known + extras


def _text_without_sections(text: str, sections: list[dict], names: set[str]) -> str:
    lines = text.splitlines()
    excluded: set[int] = set()
    for section in sections:
        if section["name"] in names:
            excluded.update(range(section["start"], section["end"]))
    return "\n".join(line for idx, line in enumerate(lines) if idx not in excluded)


def _detect_sections(text: str) -> list[dict]:
    lines = text.splitlines()
    found: list[dict] = []
    for idx, line in enumerate(lines):
        header = _normalize_header(line)
        for pattern, name in (
            (_REQUIRED_SECTION, "required"),
            (_PREFERRED_SECTION, "preferred"),
            (_RESPONSIBILITIES_SECTION, "responsibilities"),
            (_TITLE_SECTION, "title"),
        ):
            if pattern.match(header) and len(header) < 80:
                found.append({"name": name, "start": idx, "end": len(lines)})
                break
    found.sort(key=lambda s: s["start"])
    for i in range(len(found) - 1):
        found[i]["end"] = found[i + 1]["start"]
    return found


def _extract_title(text: str, sections: list[dict]) -> str:
    title_sec = next((s for s in sections if s["name"] == "title"), None)
    if title_sec:
        lines = text.splitlines()[title_sec["start"] + 1 : title_sec["end"]]
        first = next(
            (
                _MD_HEADER.sub("", ln).strip()
                for ln in lines
                if ln.strip() and len(_MD_HEADER.sub("", ln).strip()) < 80
            ),
            None,
        )
        if first:
            return first
    for line in text.splitlines():
        line = _MD_HEADER.sub("", line).strip()
        if not line or len(line) > 70 or _SECTION_HEADER.match(line):
            continue
        if 8 <= len(line) <= 60:
            return line
    return ""


def _extract_industry(text: str) -> str | None:
    industries = {
        "banking": r"\bbanking\b|\bfinancial services\b|\bfintech\b",
        "fintech": r"\bfintech\b",
        "e-commerce": r"\be[- ]commerce\b|\bonline retail\b",
        "healthcare": r"\bhealthcare\b|\bhealth[- ]tech\b|\bhospital\b",
        "gaming": r"\bgaming\b|\bgames\b",
        "logistics": r"\blogistics\b|\bshipping\b|\bsupply chain\b",
        "education": r"\bed[- ]tech\b|\beducation\b",
        "ai": r"\bartificial intelligence\b|\bai[- ]?powered\b",
        "security": r"\bcybersecurity\b|\bsecurity\b",
        "saas": r"\bsaas\b|\bsoftware as a service\b",
    }
    low = text.lower()
    for industry, pattern in industries.items():
        if re.search(pattern, low):
            return industry
    return None


def _extract_education(text: str) -> str | None:
    m = _EDUCATION_RE.search(text)
    if not m:
        return None
    token = re.sub(r"[\s.'’]+", "", m.group(0).lower())
    for key in ("phd", "doctorate", "doktor", "s3"):
        if key in token:
            return "phd"
    for key in ("mba", "msc", "master", "magister", "s2", "ms", "ma"):
        if key in token:
            return "msc"
    for key in ("bsc", "bachelor", "sarjana", "s1", "bs", "ba"):
        if key in token:
            return "bsc"
    if "diploma" in token or "d3" in token or "associate" in token:
        return "diploma"
    return None


def _extract_responsibilities(block: str) -> list[str]:
    out: list[str] = []
    for line in block.splitlines():
        line = line.strip().lstrip("-•*◦").strip()
        if 12 <= len(line) <= 200 and not _DATE_ONLY.match(line) and not _SECTION_HEADER.match(line):
            out.append(line)
    return out[:20]


def _first(pattern: re.Pattern, text: str) -> str | None:
    m = pattern.search(text)
    return m.group(0).lower() if m else None
