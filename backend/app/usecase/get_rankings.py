from app.domain.candidate import Candidate
from app.domain.errors import NotFoundError
from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository


class GetRankings:
    def __init__(self, repo: JobRepository, cv_repo: CvRepository):
        self.repo = repo
        self.cv_repo = cv_repo

    async def execute(self, job_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        cvs = await self.cv_repo.find_by_job(job_id)
        ranked = [cv for cv in cvs if cv.overall_score is not None]
        ranked.sort(key=Candidate.ranking_key, reverse=True)
        for i, cv in enumerate(ranked):
            cv.rank = i + 1
        return {
            "job_id": job_id,
            "count": len(ranked),
            "results": [cv.to_json() for cv in ranked],
        }
