from app.config import Settings, settings
from app.database.db_client import DbClient
from app.database.datasource.job_datasource import JobDatasource
from app.database.datasource.cv_datasource import CvDatasource
from app.repository.job_repository import JobRepository
from app.repository.impl.job_repository_impl import JobRepositoryImpl
from app.repository.cv_repository import CvRepository
from app.repository.impl.cv_repository_impl import CvRepositoryImpl
from app.usecase.get_job_by_page import GetJobByPage
from app.usecase.save_job import SaveJob
from app.usecase.get_job import GetJob
from app.usecase.delete_job import DeleteJob
from app.usecase.upload_cvs import UploadCvs
from app.usecase.list_cvs import ListCvs
from app.usecase.delete_cv import DeleteCv
from app.usecase.rank_job import RankJob
from app.usecase.rank_cv import RankCv
from app.usecase.get_rankings import GetRankings

"""DATASOURCE"""
__db_client = DbClient()
__job_datasource = JobDatasource(__db_client)
__cv_datasource = CvDatasource(__db_client)


"""REPOSITORY"""
def __job_repo() -> JobRepository:
    return JobRepositoryImpl(__job_datasource)

def __cv_repo() -> CvRepository:
    return CvRepositoryImpl(__cv_datasource)


"""USE CASE"""
def saveJobUseCase() -> SaveJob:
    return SaveJob(__job_repo())

def get_job_by_page_use_case() -> GetJobByPage:
    return GetJobByPage(__job_repo(), __cv_repo())

def get_job_use_case() -> GetJob:
    return GetJob(__job_repo(), __cv_repo())

def delete_job_use_case() -> DeleteJob:
    return DeleteJob(__job_repo(), __cv_repo())

def upload_cvs_use_case() -> UploadCvs:
    return UploadCvs(__job_repo(), __cv_repo(), _settings())

def list_cvs_use_case() -> ListCvs:
    return ListCvs(__job_repo(), __cv_repo())

def delete_cv_use_case() -> DeleteCv:
    return DeleteCv(__job_repo(), __cv_repo())

def rank_job_use_case() -> RankJob:
    return RankJob(__job_repo(), __cv_repo(), _settings())

def rank_cv_use_case() -> RankCv:
    return RankCv(__job_repo(), __cv_repo(), _settings())

def get_rankings_use_case() -> GetRankings:
    return GetRankings(__job_repo(), __cv_repo())


def _settings() -> Settings:
    return settings
