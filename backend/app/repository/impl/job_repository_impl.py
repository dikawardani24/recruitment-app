from app.domain.job import Job
from app.domain.page import Page
from app.database.datasource.job_datasource import JobDatasource

class JobRepositoryImpl: 
    def __init__(self, datasource: JobDatasource):
        self.datasource = datasource
        
    async def save(self, job: Job):
        entity = job.to_entity()
        await self.datasource.save(entity)

    async def get_job(self, page: int, page_size: int)-> Page[Job]:
        offset = (page - 1) * page_size
        limit = page_size + 1

        entities = await self.datasource.find_by_limit_and_offset(
            limit= limit,
            offset= offset
        )

        has_more = len(entities) > page_size
        domains = [Job.from_entity(row) for row in entities[:page_size]]
        return Page(
            page=page,
            page_size=page_size,
            data=domains,
            last_page=not has_more
        )

    async def get_by_id(self, job_id: str) -> Job | None:
        entity = await self.datasource.find_by_id(job_id)
        if entity:
            return Job.from_entity(entity)
        return None

    async def delete(self, job_id: str):
        await self.datasource.delete(job_id)
        