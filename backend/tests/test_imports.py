from __future__ import annotations

import asyncio
import time
from pathlib import Path

import pytest

from app.config import settings
from app.extraction import Profile
from tests.conftest import (
    JUNIOR_BACKEND,
    SENIOR_BACKEND,
    create_job,
    upload_cvs,
    wait_for_import,
)


def _profile(name: str = "Jane Doe") -> Profile:
    return Profile(
        candidate_name=name,
        skills=["Python"],
        years_experience=5.0,
        education="Bachelor of Science",
        certifications=[],
        profile_text=f"{name}\nPython\n5 years\n",
    )


def test_batch_upload_returns_immediately_with_import(client, cv_builder):
    job_id = create_job(client)

    start = time.monotonic()
    resp = upload_cvs(client, job_id, cv_builder, ("jane.txt", SENIOR_BACKEND), ("bob.txt", JUNIOR_BACKEND))
    elapsed = time.monotonic() - start

    assert resp["status"] == "submitted"
    assert resp["total_files"] == 2
    assert resp["batch_files"] == 2
    assert resp["import_id"]

    # The request must not wait for extraction.
    assert elapsed < 1.0

    status = wait_for_import(client, job_id, resp["import_id"])
    assert status["status"] == "completed"
    assert status["total"] == 2
    assert status["processed"] == 2
    assert status["failed"] == 0


def test_batch_upload_appends_to_existing_import(client, cv_builder):
    job_id = create_job(client)

    first = upload_cvs(client, job_id, cv_builder, ("jane.txt", SENIOR_BACKEND))
    import_id = first["import_id"]

    second = upload_cvs(
        client,
        job_id,
        cv_builder,
        ("bob.txt", JUNIOR_BACKEND),
        ("amy.txt", JUNIOR_BACKEND),
        import_id=import_id,
    )
    assert second["import_id"] == import_id
    assert second["total_files"] == 3

    status = wait_for_import(client, job_id, import_id)
    assert status["status"] == "completed"
    assert status["total"] == 3
    assert status["processed"] == 3

    cvs = client.get(f"/api/jobs/{job_id}/cvs").json()["results"]
    assert len(cvs) == 3


def test_upload_unknown_job_returns_404(client, cv_builder):
    resp = client.post(
        "/api/jobs/00000000-0000-0000-0000-000000000000/candidates/import",
        files=[("files", cv_builder("jane.txt", SENIOR_BACKEND))],
    )
    assert resp.status_code == 404


def test_upload_with_unknown_import_returns_404(client, cv_builder):
    job_id = create_job(client)
    resp = client.post(
        f"/api/jobs/{job_id}/candidates/import",
        files=[("files", cv_builder("jane.txt", SENIOR_BACKEND))],
        data={"import_id": "nope"},
    )
    assert resp.status_code == 404


def test_upload_failure_per_file_does_not_block_batch(client, cv_builder):
    """A file that cannot be parsed is marked failed; the rest still process."""
    job_id = create_job(client)

    resp = upload_cvs(
        client,
        job_id,
        cv_builder,
        ("good.txt", SENIOR_BACKEND),
        ("broken.txt", JUNIOR_BACKEND),
        ("evil.exe", "not a document"),
    )
    import_id = resp["import_id"]

    status = wait_for_import(client, job_id, import_id)
    assert status["status"] == "partially_failed"
    assert status["processed"] == 2
    assert status["failed"] == 1

    cvs = client.get(f"/api/jobs/{job_id}/cvs").json()["results"]
    by_name = {c["file_name"]: c for c in cvs}
    assert by_name["good.txt"]["status"] == "completed"
    assert by_name["broken.txt"]["status"] == "completed"
    assert by_name["evil.exe"]["status"] == "failed"
    assert by_name["evil.exe"]["error"]


def test_processing_failure_marks_only_bad_document_failed(client, cv_builder):
    job_id = create_job(client)

    resp = upload_cvs(
        client,
        job_id,
        cv_builder,
        ("jane.txt", SENIOR_BACKEND),
        ("unknown.xyz", "not a supported document"),
    )
    status = wait_for_import(client, job_id, resp["import_id"])
    assert status["status"] == "partially_failed"
    assert status["processed"] == 1
    assert status["failed"] == 1


def test_import_status_reports_progress(client, cv_builder, monkeypatch):
    job_id = create_job(client)

    async def slow_pipeline(settings_, file_path, file_name):
        await asyncio.sleep(0.05)
        return _profile("Jane Doe"), "rules"

    monkeypatch.setattr("app.imports.processor.extract_and_profile", slow_pipeline)

    resp = upload_cvs(client, job_id, cv_builder, ("a.txt", SENIOR_BACKEND), ("b.txt", JUNIOR_BACKEND))
    import_id = resp["import_id"]

    # Processing is asynchronous: right after upload the import is not terminal.
    observed_terminal = False
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        status = client.get(f"/api/jobs/{job_id}/imports/{import_id}").json()
        assert status["total"] == 2
        if status["status"] == "completed":
            observed_terminal = True
            assert status["processed"] == 2
            break
        time.sleep(0.01)

    assert observed_terminal


def test_concurrent_processing_is_bounded(client, cv_builder, monkeypatch):
    job_id = create_job(client)
    concurrency = settings.import_worker_concurrency

    active = 0
    max_active = 0
    lock = asyncio.Lock()

    async def tracked_pipeline(settings_, file_path, file_name):
        nonlocal active, max_active
        async with lock:
            active += 1
            max_active = max(max_active, active)
        try:
            await asyncio.sleep(0.05)
            return _profile(file_name), "rules"
        finally:
            async with lock:
                active -= 1

    monkeypatch.setattr("app.imports.processor.extract_and_profile", tracked_pipeline)

    specs = [(f"cv{i}.txt", SENIOR_BACKEND) for i in range(12)]
    resp = upload_cvs(client, job_id, cv_builder, *specs)
    wait_for_import(client, job_id, resp["import_id"])

    # More than one CV is processed at the same time (real concurrency)...
    assert max_active >= 2
    # ...but never more than the configured worker count (bounded).
    assert max_active <= concurrency


def test_all_failed_import(client, cv_builder):
    job_id = create_job(client)

    resp = upload_cvs(client, job_id, cv_builder, ("one.exe", "bad"), ("two.bin", "bad"))
    status = wait_for_import(client, job_id, resp["import_id"])
    assert status["status"] == "failed"
    assert status["processed"] == 0
    assert status["failed"] == 2


def test_import_status_unknown_404(client):
    job_id = create_job(client)
    assert (
        client.get(f"/api/jobs/{job_id}/imports/nope").status_code == 404
    )
    assert (
        client.get(
            "/api/jobs/00000000-0000-0000-0000-000000000000/imports/nope"
        ).status_code
        == 404
    )


def test_import_from_another_job_returns_404(client, cv_builder):
    job_a = create_job(client, title="A")
    job_b = create_job(client, title="B")

    resp = upload_cvs(client, job_a, cv_builder, ("jane.txt", SENIOR_BACKEND))
    import_id = resp["import_id"]

    assert client.get(f"/api/jobs/{job_b}/imports/{import_id}").status_code == 404


@pytest.mark.asyncio
async def test_restart_recovers_stuck_documents(tmp_path: Path):
    """Documents stuck in PROCESSING after a crash are re-queued on startup."""
    from app import db as app_db
    from app.database.datasource.cv_datasource import CvDatasource
    from app.database.datasource.import_job_datasource import ImportJobDatasource
    from app.database.db_client import DbClient
    from app.di.injection import cv_processor
    from app.domain.candidate import Candidate
    from app.domain.import_job import ImportJob
    from app.repository.impl.cv_repository_impl import CvRepositoryImpl
    from app.repository.impl.import_job_repository_impl import ImportJobRepositoryImpl

    settings.db_path = tmp_path / "test.db"
    settings.upload_dir = tmp_path / "uploads"
    settings.ensure_dirs()
    await app_db.init_db()

    db = DbClient()
    cv_repo = CvRepositoryImpl(CvDatasource(db))
    import_repo = ImportJobRepositoryImpl(ImportJobDatasource(db))

    imp = ImportJob(id="imp-1", job_id="job-1", status="processing", total_files=1)
    await import_repo.create(imp)
    await cv_repo.save(
        Candidate(
            id="cv-1",
            job_id="job-1",
            import_job_id="imp-1",
            file_name="a.txt",
            storage_path="/tmp/none",
            status="processing",
        )
    )

    processor = cv_processor()
    await processor.reset_stale_processing()

    docs = await cv_repo.find_uploaded(10)
    assert len(docs) == 1
    assert docs[0].status == "uploaded"


def test_legacy_cvs_endpoint_still_works(client, cv_builder):
    """The old POST /cvs route is kept as a compatibility alias."""
    job_id = create_job(client)
    resp = client.post(
        f"/api/jobs/{job_id}/cvs",
        files=[("files", cv_builder("jane.txt", SENIOR_BACKEND))],
    )
    assert resp.status_code == 202
    body = resp.json()
    assert body["import_id"]
    status = wait_for_import(client, job_id, body["import_id"])
    assert status["status"] == "completed"
