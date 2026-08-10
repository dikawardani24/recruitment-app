from app.config import Settings, settings
from app.database.db_client import DbClient
from app.database.datasource.job_datasource import JobDatasource
from app.database.datasource.cv_datasource import CvDatasource
from app.database.datasource.import_job_datasource import ImportJobDatasource
from app.repository.job_repository import JobRepository
from app.repository.impl.job_repository_impl import JobRepositoryImpl
from app.repository.cv_repository import CvRepository
from app.repository.impl.cv_repository_impl import CvRepositoryImpl
from app.repository.import_job_repository import ImportJobRepository
from app.repository.impl.import_job_repository_impl import ImportJobRepositoryImpl
from app.usecase.get_job_by_page import GetJobByPage
from app.usecase.search_jobs import SearchJobs
from app.usecase.save_job import SaveJob
from app.usecase.get_job import GetJob
from app.usecase.delete_job import DeleteJob
from app.usecase.import_cv_batch import ImportCvBatch
from app.usecase.list_cvs import ListCvs
from app.usecase.get_import_status import GetImportStatus
from app.usecase.delete_cv import DeleteCv
from app.usecase.rank_job import RankJob
from app.usecase.rank_cv import RankCv
from app.usecase.get_rankings import GetRankings
from app.usecase.semantic_search import SemanticSearch
from app.usecase.reindex_embeddings import ReindexEmbeddings
from app.usecase.ask import Ask
from app.chat import ChatClient
from app.rag import EmbeddingIndexer, LocalEmbedder, VectorStore
from app.imports.processor import CvProcessor

"""DATASOURCE"""
__db_client = DbClient()
__job_datasource = JobDatasource(__db_client)
__cv_datasource = CvDatasource(__db_client)
__import_datasource = ImportJobDatasource(__db_client)


"""REPOSITORY"""
def __job_repo() -> JobRepository:
    return JobRepositoryImpl(__job_datasource)

def __cv_repo() -> CvRepository:
    return CvRepositoryImpl(__cv_datasource)

def __import_repo() -> ImportJobRepository:
    return ImportJobRepositoryImpl(__import_datasource)


"""USE CASE"""
def saveJobUseCase() -> SaveJob:
    return SaveJob(__job_repo(), _embedding_indexer())

def get_job_by_page_use_case() -> GetJobByPage:
    return GetJobByPage(__job_repo(), __cv_repo())

def search_jobs_use_case() -> SearchJobs:
    return SearchJobs(__job_repo(), __cv_repo())

def get_job_use_case() -> GetJob:
    return GetJob(__job_repo(), __cv_repo())

def delete_job_use_case() -> DeleteJob:
    return DeleteJob(__job_repo(), __cv_repo(), __import_repo(), _embedding_indexer())

def import_cv_batch_use_case() -> ImportCvBatch:
    return ImportCvBatch(__job_repo(), __cv_repo(), __import_repo(), _settings())

def list_cvs_use_case() -> ListCvs:
    return ListCvs(__job_repo(), __cv_repo())

def get_import_status_use_case() -> GetImportStatus:
    return GetImportStatus(__job_repo(), __cv_repo(), __import_repo())

def delete_cv_use_case() -> DeleteCv:
    return DeleteCv(__job_repo(), __cv_repo(), _embedding_indexer())

def rank_job_use_case() -> RankJob:
    return RankJob(__job_repo(), __cv_repo(), _settings())

def rank_cv_use_case() -> RankCv:
    return RankCv(__job_repo(), __cv_repo(), _settings())

def get_rankings_use_case() -> GetRankings:
    return GetRankings(__job_repo(), __cv_repo())

def semantic_search_use_case() -> SemanticSearch:
    return SemanticSearch(_embedding_indexer(), __job_repo(), __cv_repo())

def reindex_embeddings_use_case() -> ReindexEmbeddings:
    return ReindexEmbeddings(_embedding_indexer(), __job_repo(), __cv_repo())

def ask_use_case() -> Ask:
    return Ask(_settings(), _chat_client(), _embedding_indexer())


"""CHAT CLIENT"""
__chat_client: ChatClient | None = None

def _chat_client() -> ChatClient:
    global __chat_client
    if __chat_client is None:
        __chat_client = ChatClient(_settings())
    return __chat_client


"""RAG INDEXER"""
__embedding_indexer: EmbeddingIndexer | None = None

def _embedding_indexer() -> EmbeddingIndexer | None:
    """Lazily build the indexer only when RAG is enabled, so disabled installs
    never import/construct Qdrant or load embedding models."""
    global __embedding_indexer
    if not settings.rag_enabled:
        return None
    if __embedding_indexer is None:
        embedder = LocalEmbedder(settings)
        store = VectorStore(settings)
        __embedding_indexer = EmbeddingIndexer(settings, embedder, store)
    return __embedding_indexer


"""WORKER"""
__cv_processor: CvProcessor | None = None

def cv_processor() -> CvProcessor:
    global __cv_processor
    if __cv_processor is None:
        __cv_processor = CvProcessor(
            _settings(), __cv_repo(), __import_repo(), _embedding_indexer()
        )
    return __cv_processor


def _settings() -> Settings:
    return settings
