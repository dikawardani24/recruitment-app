from app.repository.job_repository import JobRepository
from app.repository.cv_repository import CvRepository
from app.repository.import_job_repository import ImportJobRepository
from app.domain.errors import NotFoundError
from app.util.file_util import delete_storage_file


class DeleteJob:
    def __init__(
        self,
        repo: JobRepository,
        cv_repo: CvRepository,
        import_repo: ImportJobRepository,
    ):
        self.repo = repo
        self.cv_repo = cv_repo
        self.import_repo = import_repo

    async def execute(self, job_id: str) -> dict:
        job = await self.repo.get_by_id(job_id)
        if job is None:
            raise NotFoundError("job_not_found")

        cvs = await self.cv_repo.find_by_job(job_id)
        for cv in cvs:
            delete_storage_file(cv.storage_path)
        delete_storage_file(job.jd_file_path)

        await self.cv_repo.delete_by_job(job_id)
        await self.import_repo.delete_by_job(job_id)
        await self.repo.delete(job_id)

        return {"job_id": job_id, "deleted": True}
