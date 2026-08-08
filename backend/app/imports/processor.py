from __future__ import annotations

import asyncio
import contextlib
from datetime import datetime, timezone

from app.config import Settings
from app.domain.candidate import Candidate
from app.domain.import_job import (
    DOC_COMPLETED,
    DOC_FAILED,
    IMPORT_COMPLETED,
    IMPORT_FAILED,
    IMPORT_PARTIALLY_FAILED,
    derive_import_status,
)
from app.imports.pipeline import extract_and_profile
from app.repository.cv_repository import CvRepository
from app.repository.import_job_repository import ImportJobRepository


class CvProcessor:
    """Background CV processor.

    Runs a small pool of asyncio workers with a bounded number of concurrent
    documents. Documents are claimed from the database (DB-as-queue) so a
    Redis/Celery-style queue can be swapped in later without changing the API.
    """

    def __init__(
        self,
        settings: Settings,
        cv_repo: CvRepository,
        import_repo: ImportJobRepository,
    ):
        self.settings = settings
        self.cv_repo = cv_repo
        self.import_repo = import_repo

    async def reset_stale_processing(self) -> None:
        """Recover documents stuck in PROCESSING after a restart."""
        await self.cv_repo.reset_stale_processing()

    async def process_once(self) -> int:
        """Claim and process one round of documents. Returns how many were
        processed. Exposed for tests; the background loop uses [run]."""
        count = 0
        while True:
            doc = await self._claim_next()
            if doc is None:
                break
            count += 1
            await self._process_document(doc)
        return count

    async def run(self, stop: asyncio.Event | None = None) -> None:
        concurrency = max(1, self.settings.import_worker_concurrency)
        queue: asyncio.Queue = asyncio.Queue(maxsize=concurrency)
        workers = [
            asyncio.create_task(self._worker(queue))
            for _ in range(concurrency)
        ]
        try:
            while True:
                await self._refill(queue)
                if stop is not None and stop.is_set():
                    break
                if queue.empty():
                    await asyncio.sleep(self.settings.import_poll_interval_ms / 1000)
                else:
                    await asyncio.sleep(0)
        finally:
            # Give in-flight documents a chance to finish so no DB operation is
            # interrupted mid-write, then shut the workers down.
            with contextlib.suppress(asyncio.TimeoutError):
                await asyncio.wait_for(queue.join(), timeout=5)
            for worker in workers:
                worker.cancel()
            for worker in workers:
                with contextlib.suppress(asyncio.CancelledError):
                    await worker

    async def _refill(self, queue: asyncio.Queue) -> None:
        while queue.qsize() < max(1, self.settings.import_worker_concurrency):
            doc = await self._claim_next()
            if doc is None:
                break
            queue.put_nowait(doc)

    async def _claim_next(self) -> Candidate | None:
        docs = await self.cv_repo.find_uploaded(1)
        if not docs:
            return None
        doc = docs[0]
        await self.cv_repo.mark_processing(doc.id)
        return doc

    async def _worker(self, queue: asyncio.Queue) -> None:
        while True:
            doc = await queue.get()
            try:
                await self._process_document(doc)
            except asyncio.CancelledError:
                raise
            except Exception:
                await self.cv_repo.mark_failed(doc.id, "internal_error")
                await self._refresh_import(doc.import_job_id)
            finally:
                queue.task_done()

    async def _process_document(self, doc: Candidate) -> None:
        try:
            profile, source = await extract_and_profile(
                self.settings, doc.storage_path, doc.file_name
            )
            candidate = Candidate(
                id=doc.id,
                job_id=doc.job_id,
                import_job_id=doc.import_job_id,
                file_name=doc.file_name,
                storage_path=doc.storage_path,
                status=DOC_COMPLETED,
                candidate_name=profile.candidate_name,
                profile_text=profile.profile_text,
                skills=profile.skills,
                years_experience=profile.years_experience,
                education=profile.education,
                certifications=profile.certifications,
                source=source,
            )
            await self.cv_repo.complete_document(candidate)
        except Exception as exc:
            await self.cv_repo.mark_failed(doc.id, _error_str(exc))
        finally:
            await self._refresh_import(doc.import_job_id)

    async def _refresh_import(self, import_id: str | None) -> None:
        if not import_id:
            return
        import_job = await self.import_repo.get(import_id)
        if import_job is None:
            return
        counts = await self.cv_repo.count_by_import(import_id)
        total = sum(counts.values())
        processed = counts.get(DOC_COMPLETED, 0)
        failed = counts.get(DOC_FAILED, 0)

        now = datetime.now(timezone.utc).isoformat()
        new_status = derive_import_status(total, processed, failed)
        # A terminal import must not be downgraded by a concurrently-observed
        # stale snapshot (several workers finish around the same time).
        if (
            import_job.status in (IMPORT_COMPLETED, IMPORT_PARTIALLY_FAILED, IMPORT_FAILED)
            and new_status not in (IMPORT_COMPLETED, IMPORT_PARTIALLY_FAILED, IMPORT_FAILED)
        ):
            new_status = import_job.status

        import_job.total_files = total
        import_job.uploaded_files = total
        import_job.processed_files = processed
        import_job.failed_files = failed
        import_job.status = new_status
        import_job.updated_at = now
        if new_status in (
            IMPORT_COMPLETED,
            IMPORT_PARTIALLY_FAILED,
            IMPORT_FAILED,
        ):
            import_job.completed_at = import_job.completed_at or now
        await self.import_repo.update(import_job)


def _error_str(exc: Exception) -> str:
    message = f"{type(exc).__name__}: {exc}"
    return message[:500]
