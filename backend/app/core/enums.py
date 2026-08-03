from __future__ import annotations

from enum import Enum


class UserRole(str, Enum):
    APPLICANT = "applicant"
    RECRUITER = "recruiter"
    ADMIN = "admin"


class ResumeStatus(str, Enum):
    QUEUED = "queued"
    PARSING = "parsing"
    OCR = "ocr"
    STRUCTURING = "structuring"
    CHUNKING = "chunking"
    INDEXING = "indexing"
    INDEXED = "indexed"
    FAILED = "failed"


class CandidateStatus(str, Enum):
    NEW = "new"
    NEEDS_REVIEW = "needs_review"
    SCREENED = "screened"
    SHORTLISTED = "shortlisted"
    INTERVIEW = "interview"
    HIRED = "hired"
    REJECTED = "rejected"


class ApplicationStatus(str, Enum):
    APPLIED = "applied"
    REVIEWING = "reviewing"
    SHORTLISTED = "shortlisted"
    INTERVIEW = "interview"
    OFFERED = "offered"
    HIRED = "hired"
    REJECTED = "rejected"


class Section(str, Enum):
    SUMMARY = "summary"
    SKILLS = "skills"
    EXPERIENCE = "experience"
    EDUCATION = "education"
    CERTIFICATIONS = "certifications"
    PROJECTS = "projects"


class RankingBucket(str, Enum):
    BEST = "best"
    STRONG = "strong"
    HIDDEN_GEM = "hidden_gem"
    ALTERNATIVE = "alternative"


class ChunkIndexStatus(str, Enum):
    PENDING = "pending"
    INDEXED = "indexed"
    FAILED = "failed"


class SkillSource(str, Enum):
    PARSED = "parsed"
    INFERRED = "inferred"
