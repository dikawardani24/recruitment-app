from __future__ import annotations

from dataclasses import dataclass, field
from uuid import UUID

from app.core.enums import ApplicationStatus, CandidateStatus, RankingBucket, Section, SkillSource


@dataclass(frozen=True)
class Email:
    value: str

    def __post_init__(self) -> None:
        if "@" not in self.value or self.value.count("@") != 1:
            raise ValueError(f"Invalid email: {self.value}")


@dataclass(frozen=True)
class DateRange:
    start: str | None  # YYYY-MM
    end: str | None  # YYYY-MM, None == present

    def years(self) -> float:
        if self.start is None:
            return 0.0
        start_y, start_m = (int(x) for x in self.start.split("-"))
        if self.end is None:
            end_y, end_m = 2026, 8  # now — injected by service in practice
        else:
            end_y, end_m = (int(x) for x in self.end.split("-"))
        return round((end_y - start_y) + (end_m - start_m) / 12.0, 2)


@dataclass(frozen=True)
class Skill:
    name: str
    category: str | None = None


@dataclass(frozen=True)
class Experience:
    company: str
    position: str
    start_date: str | None
    end_date: str | None
    responsibilities: list[str] = field(default_factory=list)

    def date_range(self) -> DateRange:
        return DateRange(self.start_date, self.end_date)


@dataclass(frozen=True)
class Education:
    institution: str
    degree: str
    field: str | None = None
    start_year: int | None = None
    end_year: int | None = None


@dataclass(frozen=True)
class Certification:
    name: str
    issuer: str | None = None
    year: int | None = None


@dataclass(frozen=True)
class Project:
    name: str
    description: str = ""
    url: str | None = None
    highlights: list[str] = field(default_factory=list)


@dataclass
class CandidateProfile:
    candidate: dict
    summary: str = ""
    skills: list[str] = field(default_factory=list)
    experience: list[Experience] = field(default_factory=list)
    education: list[Education] = field(default_factory=list)
    certifications: list[Certification] = field(default_factory=list)
    projects: list[Project] = field(default_factory=list)


@dataclass
class Candidate:
    id: UUID
    name: str
    email: Email | None
    phone: str | None
    location: str | None
    summary: str
    profile: CandidateProfile
    derived_metrics: dict = field(default_factory=dict)
    status: CandidateStatus = CandidateStatus.NEW


@dataclass
class Resume:
    id: UUID
    candidate_id: UUID
    file_key: str
    file_name: str
    status: object  # ResumeStatus
    extracted_text: str = ""
    parsing_meta: dict = field(default_factory=dict)
    error_detail: dict | None = None
    embedding_model: str | None = None
    embedding_version: int = 0


@dataclass
class SemanticChunk:
    id: UUID
    candidate_id: UUID
    candidate_name: str
    resume_id: UUID
    section: Section
    text: str
    version: int
    embedding_model: str


@dataclass(frozen=True)
class VectorHit:
    chunk_id: UUID
    candidate_id: UUID
    candidate_name: str
    resume_id: UUID
    section: Section
    text: str
    score: float


@dataclass
class CandidateRanking:
    candidate_id: UUID
    candidate_name: str
    bucket: RankingBucket
    overall_score: float
    skill_score: float
    experience_score: float
    education_score: float
    certification_score: float
    strengths: list[str] = field(default_factory=list)
    weaknesses: list[str] = field(default_factory=list)
    explanation: str = ""
    recommendation: str = ""
    evidence: list[VectorHit] = field(default_factory=list)
