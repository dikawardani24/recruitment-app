from __future__ import annotations

import json

from app.database.entities.cv_entity import CvEntity


def _loads(value):
    if value is None:
        return None
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return None


def _dumps(value):
    return json.dumps(value) if value is not None else None


class Candidate:
    def __init__(
        self,
        id: str,
        job_id: str,
        file_name: str,
        storage_path: str,
        status: str,
        import_job_id: str | None = None,
        created_at: str = "",
        candidate_name: str | None = None,
        profile_text: str | None = None,
        skills: list[str] | None = None,
        years_experience: float | None = None,
        education: str | None = None,
        certifications: list[str] | None = None,
        overall_score: float | None = None,
        bucket: str | None = None,
        recommendation: str | None = None,
        explanation: str | None = None,
        strengths: list[str] | None = None,
        weaknesses: list[str] | None = None,
        skill_gaps: list[str] | None = None,
        skill_score: float | None = None,
        experience_score: float | None = None,
        education_score: float | None = None,
        certification_score: float | None = None,
        ranked_at: str | None = None,
        ranked_by: str | None = None,
        error: str | None = None,
        source: str | None = None,
        rank: int | None = None,
    ):
        self.id = id
        self.job_id = job_id
        self.file_name = file_name
        self.storage_path = storage_path
        self.status = status
        self.import_job_id = import_job_id
        self.created_at = created_at
        self.candidate_name = candidate_name
        self.profile_text = profile_text
        self.skills = skills or []
        self.years_experience = years_experience
        self.education = education
        self.certifications = certifications or []
        self.overall_score = overall_score
        self.bucket = bucket
        self.recommendation = recommendation
        self.explanation = explanation
        self.strengths = strengths or []
        self.weaknesses = weaknesses or []
        self.skill_gaps = skill_gaps or []
        self.skill_score = skill_score
        self.experience_score = experience_score
        self.education_score = education_score
        self.certification_score = certification_score
        self.ranked_at = ranked_at
        self.ranked_by = ranked_by
        self.error = error
        self.source = source
        self.rank = rank

    @classmethod
    def from_entity(cls, entity: CvEntity) -> "Candidate":
        return cls(
            id=entity.id,
            job_id=entity.job_id,
            file_name=entity.file_name,
            storage_path=entity.storage_path,
            status=entity.status,
            import_job_id=entity.import_job_id,
            created_at=entity.created_at,
            candidate_name=entity.candidate_name,
            profile_text=entity.profile_text,
            skills=_loads(entity.skills),
            years_experience=entity.years_experience,
            education=entity.education,
            certifications=_loads(entity.certifications),
            overall_score=entity.overall_score,
            bucket=entity.bucket,
            recommendation=entity.recommendation,
            explanation=entity.explanation,
            strengths=_loads(entity.strengths),
            weaknesses=_loads(entity.weaknesses),
            skill_gaps=_loads(entity.skill_gaps),
            skill_score=entity.skill_score,
            experience_score=entity.experience_score,
            education_score=entity.education_score,
            certification_score=entity.certification_score,
            ranked_at=entity.ranked_at,
            ranked_by=entity.ranked_by,
            error=entity.error,
            source=entity.source,
        )

    @classmethod
    def from_dict(cls, d: dict) -> "Candidate":
        return cls(
            id=d.get("id"),
            job_id=d.get("job_id"),
            file_name=d.get("file_name") or "",
            storage_path=d.get("storage_path") or "",
            status="ranked",
            import_job_id=d.get("import_job_id"),
            candidate_name=d.get("candidate_name"),
            profile_text=d.get("profile_text"),
            skills=d.get("skills") or [],
            years_experience=d.get("years_experience"),
            education=d.get("education"),
            certifications=d.get("certifications") or [],
            overall_score=d.get("overall_score"),
            bucket=d.get("bucket"),
            recommendation=d.get("recommendation"),
            explanation=d.get("explanation"),
            strengths=d.get("strengths") or [],
            weaknesses=d.get("weaknesses") or [],
            skill_gaps=d.get("skill_gaps") or [],
            skill_score=d.get("skill_score"),
            experience_score=d.get("experience_score"),
            education_score=d.get("education_score"),
            certification_score=d.get("certification_score"),
            ranked_at=d.get("ranked_at"),
            ranked_by=d.get("ranked_by"),
            error=d.get("error"),
            source=d.get("source"),
            rank=d.get("rank"),
        )

    def as_dict(self) -> dict:
        return {
            "id": self.id,
            "job_id": self.job_id,
            "import_job_id": self.import_job_id,
            "file_name": self.file_name,
            "storage_path": self.storage_path,
            "status": self.status,
            "candidate_name": self.candidate_name,
            "profile_text": self.profile_text,
            "skills": self.skills,
            "years_experience": self.years_experience,
            "education": self.education,
            "certifications": self.certifications,
            "source": self.source,
        }

    def to_entity(self) -> CvEntity:
        return CvEntity(
            id=self.id,
            job_id=self.job_id,
            import_job_id=self.import_job_id,
            created_at=self.created_at,
            file_name=self.file_name,
            storage_path=self.storage_path,
            status=self.status,
            candidate_name=self.candidate_name,
            profile_text=self.profile_text,
            skills=_dumps(self.skills),
            years_experience=self.years_experience,
            education=self.education,
            certifications=_dumps(self.certifications),
            overall_score=self.overall_score,
            bucket=self.bucket,
            recommendation=self.recommendation,
            skill_score=self.skill_score,
            experience_score=self.experience_score,
            education_score=self.education_score,
            certification_score=self.certification_score,
            strengths=_dumps(self.strengths),
            weaknesses=_dumps(self.weaknesses),
            skill_gaps=_dumps(self.skill_gaps),
            explanation=self.explanation,
            interview_questions=None,
            ranked_at=self.ranked_at,
            ranked_by=self.ranked_by,
            error=self.error,
            source=self.source,
        )

    def to_json(self) -> dict:
        return {
            "cv_id": self.id,
            "job_id": self.job_id,
            "file_name": self.file_name,
            "status": self.status,
            "candidate_name": self.candidate_name,
            "overall_score": self.overall_score,
            "bucket": self.bucket,
            "recommendation": self.recommendation,
            "explanation": self.explanation,
            "strengths": self.strengths,
            "weaknesses": self.weaknesses,
            "skill_gaps": self.skill_gaps,
            "interview_questions": None,
            "skill_score": self.skill_score,
            "experience_score": self.experience_score,
            "education_score": self.education_score,
            "certification_score": self.certification_score,
            "ranked_at": self.ranked_at,
            "ranked_by": self.ranked_by,
            "rank": self.rank,
            "source": self.source,
            "skills": self.skills,
            "years_experience": self.years_experience,
            "education": self.education,
            "certifications": self.certifications,
            "error": self.error,
        }
