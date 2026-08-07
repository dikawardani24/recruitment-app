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
    candidate_name: str | None
    profile_text: str | None
    skills: str | None
    years_experience: float | None
    education: str | None
    certifications: str | None
    overall_score: float | None
    bucket: str | None
    recommendation: str | None
    skill_score: float | None
    experience_score: float | None
    education_score: float | None
    certification_score: float | None
    strengths: str | None
    weaknesses: str | None
    skill_gaps: str | None
    explanation: str | None
    interview_questions: str | None
    ranked_at: str | None
    ranked_by: str | None
    error: str | None
    source: str | None

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "CvEntity":
        return cls(
            id=row["id"],
            job_id=row["job_id"],
            file_name=row["file_name"],
            storage_path=row["storage_path"],
            status=row["status"],
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
        )
