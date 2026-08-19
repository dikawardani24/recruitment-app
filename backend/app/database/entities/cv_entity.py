from __future__ import annotations

import sqlite3

from dataclasses import dataclass


@dataclass
class CvEntity:
    id: str
    job_id: str
    file_name: str
    storage_path: str
    status: str
    import_job_id: str | None = None
    created_at: str = ""
    candidate_name: str | None = None
    profile_text: str | None = None
    skills: str | None = None
    years_experience: float | None = None
    education: str | None = None
    certifications: str | None = None
    overall_score: float | None = None
    bucket: str | None = None
    recommendation: str | None = None
    skill_score: float | None = None
    experience_score: float | None = None
    education_score: float | None = None
    certification_score: float | None = None
    strengths: str | None = None
    weaknesses: str | None = None
    skill_gaps: str | None = None
    explanation: str | None = None
    interview_questions: str | None = None
    ranked_at: str | None = None
    ranked_by: str | None = None
    error: str | None = None
    source: str | None = None
    classification: str | None = None
    meets_job_description: bool | None = None
    relevance_score: float | None = None

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "CvEntity":
        return cls(
            id=row["id"],
            job_id=row["job_id"],
            file_name=row["file_name"],
            storage_path=row["storage_path"],
            status=row["status"],
            import_job_id=row["import_job_id"],
            created_at=row["created_at"] if "created_at" in row.keys() else "",
            candidate_name=row["candidate_name"],
            profile_text=row["profile_text"],
            skills=row["skills"],
            years_experience=row["years_experience"],
            education=row["education"],
            certifications=row["certifications"],
            overall_score=row["overall_score"],
            bucket=row["bucket"],
            recommendation=row["recommendation"],
            skill_score=row["skill_score"],
            experience_score=row["experience_score"],
            education_score=row["education_score"],
            certification_score=row["certification_score"],
            strengths=row["strengths"],
            weaknesses=row["weaknesses"],
            skill_gaps=row["skill_gaps"],
            explanation=row["explanation"],
            interview_questions=row["interview_questions"],
            ranked_at=row["ranked_at"],
            ranked_by=row["ranked_by"],
            error=row["error"],
            source=row["source"],
            classification=row["classification"] if "classification" in row.keys() else None,
            meets_job_description=bool(row["meets_job_description"]) if "meets_job_description" in row.keys() and row["meets_job_description"] is not None else None,
            relevance_score=row["relevance_score"] if "relevance_score" in row.keys() else None,
        )
