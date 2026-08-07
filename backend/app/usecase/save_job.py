from app.repository.job_repository import JobRepository
from app.domain.job import Job

class SaveJob:
    def __init__(self, repo: JobRepository):
        self.repo = repo
        pass

    async def execute(self, job: Job):
        if not job.is_data_valid():
            raise ValueError('Job data is not valid')

        await self.repo.save(job)