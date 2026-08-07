from app.repository.job_repository import JobRepository
from app.domain.page import Page
from app.domain.job import Job

class GetJobByPage:
    def __init__(self, repo: JobRepository):
            self.repo = repo
            pass

    async def execute(self, page: int, page_size: int) -> Page[Job]:
        return await self.repo.get_job(
            page = page,
            page_size= page_size
        )