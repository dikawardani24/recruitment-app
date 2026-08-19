from __future__ import annotations

from datetime import datetime, timezone

from app.config import Settings
from app.domain.errors import NotFoundError
from app.extraction import Profile
from app.ranking import RankingService
from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository


class RankCv:
    def __init__(
        self,
        repo: JobRepository,
        cv_repo: CvRepository,
        settings: Settings,
    ):
        self.repo = repo
        self.cv_repo = cv_repo
        self.settings = settings

    async def execute(self, job_id: str, cv_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")
        requirements = job.requirements()
        if not requirements:
            raise ValueError("job_missing_description")

        cv = await self.cv_repo.find_by_id(job_id, cv_id)
        if cv is None:
            raise NotFoundError("cv_not_found")
        if cv.status not in ("completed", "ranked"):
            raise ValueError("cv_not_ready")

        profile = Profile.from_cv(cv.as_dict())
        ranked, source = await RankingService(self.settings).rank(
            requirements, [profile], [cv.as_dict()]
        )
        item = ranked[0]
        item["status"] = "ranked"
        item["ranked_by"] = source
        await self.cv_repo.update_ranked(_to_candidate(item, source))

        item["rank"] = 1
        return {
            "job_id": job_id,
            "cv_id": cv_id,
            "source": source,
            "result": _cv_payload(item),
        }


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _to_candidate(item: dict, source: str):
    from app.domain.candidate import Candidate

    return Candidate(
        id=item["id"],
        job_id=item.get("job_id"),
        file_name=item.get("file_name") or "",
        storage_path=item.get("storage_path") or "",
        status="ranked",
        overall_score=item.get("overall_score"),
        bucket=item.get("bucket"),
        recommendation=item.get("recommendation"),
        explanation=item.get("explanation"),
        strengths=item.get("strengths") or [],
        weaknesses=item.get("weaknesses") or [],
        skill_gaps=item.get("skill_gaps") or [],
        skill_score=item.get("skill_score"),
        experience_score=item.get("experience_score"),
        education_score=item.get("education_score"),
        certification_score=item.get("certification_score"),
        ranked_at=item.get("ranked_at") or _now(),
        ranked_by=source,
        classification=item.get("classification"),
        meets_job_description=item.get("meets_job_description"),
        relevance_score=item.get("relevance_score"),
    )


def _cv_payload(item: dict) -> dict:
    from app.domain.candidate import Candidate

    return Candidate.from_dict(item).to_json()
