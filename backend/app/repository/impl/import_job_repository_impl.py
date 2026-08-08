from app.database.datasource.import_job_datasource import ImportJobDatasource
from app.domain.import_job import ImportJob


class ImportJobRepositoryImpl:
    def __init__(self, datasource: ImportJobDatasource):
        self.datasource = datasource

    async def create(self, import_job: ImportJob):
        await self.datasource.save(import_job.to_entity())

    async def update(self, import_job: ImportJob):
        await self.datasource.update(import_job.to_entity())

    async def get(self, import_id: str) -> ImportJob | None:
        entity = await self.datasource.get(import_id)
        if entity:
            return ImportJob.from_entity(entity)
        return None

    async def find_by_job(self, job_id: str) -> list[ImportJob]:
        entities = await self.datasource.find_by_job(job_id)
        return [ImportJob.from_entity(e) for e in entities]

    async def delete_by_job(self, job_id: str):
        await self.datasource.delete_by_job(job_id)
