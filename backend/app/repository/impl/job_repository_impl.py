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

        domains = [Job.from_entity(row) for row in entities]
        return Page(
            page=page,
            page_size=page_size,
            data=domains,
            last_page=len(domains) <= page_size
        )
        