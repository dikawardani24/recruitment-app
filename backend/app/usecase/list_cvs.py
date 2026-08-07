from app.repository.job_repository import JobRepository
from app.repository.cv_repository import CvRepository
from app.domain.errors import NotFoundError


class ListCvs:
    def __init__(self, repo: JobRepository, cv_repo: CvRepository):
        self.repo = repo
        self.cv_repo = cv_repo

    async def execute(self, job_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        cvs = await self.cv_repo.find_by_job(job_id)
        return {
            "job_id": job_id,
            "count": len(cvs),
            "results": [cv.to_json() for cv in cvs],
        }
