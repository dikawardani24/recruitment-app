from app.database.db_client import DbClient
from app.database.datasource.job_datasource import JobDatasource
from app.repository.job_repository import JobRepository
from app.repository.impl.job_repository_impl import JobRepositoryImpl
from app.usecase.get_job_by_page import GetJobByPage
from app.usecase.save_job import SaveJob

"""DATASOURCE"""
__db_client = DbClient()
__job_datasource = JobDatasource(__db_client)


"""REPOSITORY"""
def __job_repo() -> JobRepository:
    return JobRepositoryImpl(__job_datasource)

"""USE CASE"""
def saveJobUseCase() -> SaveJob:
    return SaveJob(__job_repo())

def get_job_use_case() -> GetJobByPage:
    return GetJobByPage(__job_repo())