from __future__ import annotations

from app.core.config import Settings, get_settings
from app.domain.services import SkillNormalizer, YearsExperienceCalculator
from app.infrastructure.factories import (
    EmbeddingFactory,
    LLMFactory,
    OCRFactory,
    StorageFactory,
    VectorStoreFactory,
)


class Container:
    """Composition root. Wiring happens here; nothing else builds objects."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.skill_normalizer = SkillNormalizer()
        self.years_calculator = YearsExperienceCalculator()

        from app.infrastructure.ai.chunker import SemanticChunker
        from app.infrastructure.ai.structuring import LLMStructuring

        self.chunker = SemanticChunker()
        self.structuring = LLMStructuring()

        self.embedding = EmbeddingFactory.create(self.settings)
        self.llm = LLMFactory.create(self.settings)
        self.ocr = OCRFactory.create(self.settings)
        self.vector_store = VectorStoreFactory.create(self.settings, self.embedding)
        self.storage = StorageFactory.create(self.settings)

        self.candidate_repo = self._build_candidate_repo()
        self.resume_repo = self._build_resume_repo()
        self.ranking_repo = self._build_ranking_repo()

    # -- repositories -------------------------------------------------
    def _build_candidate_repo(self):
        from app.infrastructure.persistence.repositories.candidate_repo import (
            CandidateRepository as SQLCandidateRepository,
        )

        return SQLCandidateRepository()

    def _build_resume_repo(self):
        from app.infrastructure.persistence.repositories.resume_repo import (
            ResumeRepository as SQLResumeRepository,
        )

        return SQLResumeRepository()

    def _build_ranking_repo(self):
        from app.infrastructure.persistence.repositories.ranking_repo import (
            RankingRepository as SQLRankingRepository,
        )

        return SQLRankingRepository()

    # -- use cases ----------------------------------------------------
    def upload_resume_use_case(self):
        from app.application.use_cases.resumes.upload_resume import UploadResumeUseCase

        return UploadResumeUseCase(
            resume_repo=self.resume_repo,
            storage=self.storage,
            settings=self.settings,
        )

    def process_resume_use_case(self):
        from app.application.use_cases.resumes.process_resume import ProcessResumeUseCase

        return ProcessResumeUseCase(
            resume_repo=self.resume_repo,
            candidate_repo=self.candidate_repo,
            storage=self.storage,
            settings=self.settings,
        )

    def search_candidates_use_case(self):
        from app.application.use_cases.search.search_candidates import SearchCandidatesUseCase

        return SearchCandidatesUseCase(
            embedding=self.embedding,
            vector_store=self.vector_store,
            candidate_repo=self.candidate_repo,
            settings=self.settings.search,
        )
