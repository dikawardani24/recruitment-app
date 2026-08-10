from __future__ import annotations

from dataclasses import dataclass, field

from app.domain.candidate import Candidate
from app.domain.job import Job

MAX_WINDOW_CHARS = 600
WINDOW_OVERLAP = 80

CANDIDATE_SECTIONS = ("summary", "skills", "education", "certifications", "experience")
JOB_SECTIONS = ("description", "required_skills", "preferred_skills", "responsibilities", "qualifications")


@dataclass(frozen=True)
class Chunk:
    section: str
    content: str


@dataclass
class CandidateChunks:
    candidate: Candidate
    chunks: list[Chunk] = field(default_factory=list)


@dataclass
class JobChunks:
    job: Job
    chunks: list[Chunk] = field(default_factory=list)


def _windows(text: str, max_chars: int = MAX_WINDOW_CHARS, overlap: int = WINDOW_OVERLAP) -> list[str]:
    """Split long text into bounded windows with a small overlap so a retrieval
    phrase near a boundary is not lost."""
    text = text.strip()
    if not text:
        return []
    if len(text) <= max_chars:
        return [text]
    out: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        out.append(text[start:end])
        if end >= len(text):
            break
        start = max(start + max_chars - overlap, start + 1)
    return out


def chunk_candidate(candidate: Candidate) -> list[Chunk]:
    """Semantically homogeneous chunks derived from the structured profile
    (docs/10 §2.1), adapted to the flat fields this app extracts."""
    name = candidate.candidate_name or "candidate"
    profile_text = candidate.profile_text or ""
    chunks: list[Chunk] = []

    first = _windows(profile_text)[0] if profile_text else ""
    chunks.append(Chunk("summary", f"{name} — Summary\n{first}"))

    years = candidate.years_experience
    years_label = f"{years:.1f} yrs" if years is not None else "n/a"
    for window in _windows(profile_text)[1:]:
        chunks.append(Chunk("experience", f"{name} — Experience ({years_label})\n{window}"))

    if candidate.skills:
        chunks.append(Chunk("skills", f"Skills: {', '.join(candidate.skills)}"))
    if candidate.education:
        chunks.append(Chunk("education", f"Education: {candidate.education}"))
    if candidate.certifications:
        chunks.append(Chunk("certifications", f"Certifications: {', '.join(candidate.certifications)}"))

    return chunks


def chunk_job(job: Job) -> list[Chunk]:
    """Job chunks: windowed description plus requirement groups from the parsed JD
    (docs/10 §5)."""
    chunks: list[Chunk] = []
    description = job.desc or ""
    windows = _windows(description)
    header = job.title or "Job"
    for i, window in enumerate(windows):
        text = window if i > 0 else f"{header}\n{window}"
        chunks.append(Chunk("description", text))

    requirements = job.requirements()
    if isinstance(requirements, dict):
        required = requirements.get("required_skills") or []
        preferred = requirements.get("preferred_skills") or []
        responsibilities = requirements.get("responsibilities") or []
        if required:
            chunks.append(Chunk("required_skills", f"Required skills: {', '.join(required)}"))
        if preferred:
            chunks.append(Chunk("preferred_skills", f"Preferred skills: {', '.join(preferred)}"))
        if responsibilities:
            chunks.append(Chunk("responsibilities", "\n".join(f"- {r}" for r in responsibilities)))
        quals = _qualifications_chunk(requirements)
        if quals:
            chunks.append(Chunk("qualifications", quals))

    return chunks


def _qualifications_chunk(requirements: dict) -> str:
    parts = []
    if requirements.get("education"):
        parts.append(f"Education: {requirements['education']}")
    if requirements.get("certifications"):
        parts.append(f"Certifications: {', '.join(requirements['certifications'])}")
    if requirements.get("min_years"):
        parts.append(f"Minimum years of experience: {requirements['min_years']}")
    if requirements.get("employment_type"):
        parts.append(f"Employment type: {requirements['employment_type']}")
    if requirements.get("seniority"):
        parts.append(f"Seniority: {requirements['seniority']}")
    if requirements.get("industry"):
        parts.append(f"Industry: {requirements['industry']}")
    return "\n".join(parts)
