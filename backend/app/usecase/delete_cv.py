from app.repository.job_repository import JobRepository
from app.repository.cv_repository import CvRepository
from app.domain.errors import NotFoundError
from app.util.file_util import delete_storage_file


class DeleteCv:
    def __init__(self, repo: JobRepository, cv_repo: CvRepository):
        self.repo = repo
        self.cv_repo = cv_repo

    async def execute(self, job_id: str, cv_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        cv = await self.cv_repo.find_by_id(job_id, cv_id)
        if cv is None:
            raise NotFoundError("cv_not_found")

        delete_storage_file(cv.storage_path)
        await self.cv_repo.delete(job_id, cv_id)

        return {"job_id": job_id, "cv_id": cv_id, "deleted": True}
