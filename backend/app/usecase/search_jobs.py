from app.repository.job_repository import JobRepository
from app.repository.cv_repository import CvRepository
from app.domain.page import Page
from app.domain.job import Job

class SearchJobs:
    def __init__(self, repo: JobRepository, cv_repo: CvRepository):
        self.repo = repo
        self.cv_repo = cv_repo
    
    async def __get_job(self, page: int, page_size: int, keyword: str,) -> Page[Job]:
        if len(keyword) <= 0: return await self.repo.get_job(page=page, page_size=page_size)
        return await self.repo.search_jobs(keyword, page, page_size)
    
    async def execute(self, keyword: str, page: int, page_size: int) -> dict:
        result = await self.__get_job(page_size=page_size, page=page, keyword=keyword)
        
        job_ids = [job.id for job in result.data]
        counts = await self.cv_repo.count_by_job_ids(job_ids)

        jobs = []
        for job in result.data:
            payload = job.to_json()
            payload["cv_count"] = counts.get(job.id, 0)
            jobs.append(payload)

        return {
            "count": len(jobs),
            "jobs": jobs,
            "meta": {
                "page": page,
                "limit": page_size,
                "has_more": not result.last_page,
            },
        }
