from __future__ import annotations

import hashlib
from uuid import uuid4

from app.core.config import PipelineSettings
from app.core.enums import CandidateStatus, ResumeStatus
from app.core.ports import CandidateRepository, ObjectStorage, ResumeRepository
from app.domain.entities import Resume


class UploadResumeUseCase:
    def __init__(
        self,
        resume_repo: ResumeRepository,
        storage: ObjectStorage,
        settings: PipelineSettings,
    ) -> None:
        self._repo = resume_repo
        self._storage = storage
        self._settings = settings

    async def execute(self, file_name: str, content: bytes) -> tuple[Resume, bool]:
        if len(content) > self._settings.max_file_size_mb * 1024 * 1024:
            raise ValueError("file_too_large")

        digest = hashlib.sha256(content).hexdigest()
        existing = await self._repo.get_by_hash(digest)
        if existing:
            return existing, False  # idempotent re-upload

        resume = Resume(
            id=uuid4(),
            candidate_id=None,  # resolved after structuring
            file_key=f"{digest[:2]}/{digest}.pdf",
            file_name=file_name,
            status=ResumeStatus.QUEUED,
            parsing_meta={"sha256": digest},
        )
        await self._storage.put(resume.file_key, content, "application/pdf")
        await self._repo.create(resume)
        return resume, True


class ProcessResumeUseCase:
    """Pipeline orchestrator (doc 07 §7). Each stage is idempotent."""

    def __init__(
        self,
        resume_repo: ResumeRepository,
        candidate_repo: CandidateRepository,
        storage: ObjectStorage,
        settings: PipelineSettings,
    ) -> None:
        self._resume_repo = resume_repo
        self._candidate_repo = candidate_repo
        self._storage = storage
        self._settings = settings

    async def execute(self, resume_id) -> None:
        resume = await self._resume_repo.get(resume_id)
        if resume is None or resume.status in {ResumeStatus.INDEXED, ResumeStatus.FAILED}:
            return

        try:
            data = await self._storage.get(resume.file_key)
            text, meta = await self._extract(data)
            resume.extracted_text = text
            resume.parsing_meta.update(meta)

            profile = await self._structure(resume)
            candidate = await self._persist_candidate(resume, profile)
            await self._index(resume, candidate)
        except Exception as exc:
            resume.status = ResumeStatus.FAILED
            resume.error_detail = {"stage": "unknown", "message": str(exc)}
            await self._resume_repo.save(resume)
            raise

    # -- stage hooks (overridden by infra-provided implementations) --
    async def _extract(self, data: bytes) -> tuple[str, dict]:
        from app.infrastructure.providers.parsers.pdf_digital import PdfPlumberParser

        parser = PdfPlumberParser()
        return await parser.extract_text(data)

    async def _structure(self, resume: Resume):
        from app.infrastructure.ai.structuring import LLMStructuring

        return await LLMStructuring().structure(resume.extracted_text)

    async def _persist_candidate(self, resume: Resume, profile):
        from app.domain.entities import Candidate, CandidateProfile

        candidate = Candidate(
            id=uuid4(),
            name=profile["candidate"].get("name", "Unknown"),
            email=None,
            phone=profile["candidate"].get("phone"),
            location=profile["candidate"].get("location"),
            summary=profile.get("summary", ""),
            profile=CandidateProfile(
                candidate=profile["candidate"],
                summary=profile.get("summary", ""),
                skills=profile.get("skills", []),
            ),
            status=CandidateStatus.NEW,
        )
        candidate = await self._candidate_repo.save(candidate)
        resume.candidate_id = candidate.id
        await self._resume_repo.save(resume)
        return candidate

    async def _index(self, resume: Resume, candidate) -> None:
        from app.core.container import Container

        container = Container()
        chunks = container.chunker.chunk(candidate, resume.id) if hasattr(container, "chunker") else []
        if chunks:
            for c in chunks:
                c.embedding_model = container.embedding.model_name
                c.version = container.settings.embedding.dimension  # placeholder version
            await container.vector_store.upsert(chunks, container.embedding.model_name, 1)
        resume.status = ResumeStatus.INDEXED
        resume.embedding_model = container.embedding.model_name
        resume.embedding_version = 1
        await self._resume_repo.save(resume)
