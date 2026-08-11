from __future__ import annotations

import tempfile
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import settings
from app.database.db_client import DbClient


@pytest.fixture()
def client(tmp_path: Path):
    settings.db_path = tmp_path / "test.db"
    settings.upload_dir = tmp_path / "uploads"
    settings.llm_api_key = None
    settings.import_poll_interval_ms = 20
    settings.rag_enabled = False
    settings.ensure_dirs()

    import asyncio

    asyncio.run(DbClient().init_scheme())

    from app.main import app

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def cv_builder(tmp_path: Path):
    def build(name: str, body: str) -> tuple[str, bytes, str]:
        path = tmp_path / name
        path.write_text(body)
        return name, path.read_bytes(), "text/plain"

    return build


def create_job(client, title="Senior Backend Engineer", description=None) -> str:
    if description is None:
        description = BACKEND_JD
    resp = client.post("/api/jobs", data={"title": title, "description": description})
    assert resp.status_code == 201, resp.text
    return resp.json()["job"]["job_id"]


def upload_cvs(client, job_id, cv_builder, *specs, **kwargs) -> dict:
    """Upload one batch of CVs. `specs` are (name, body) tuples."""
    import_id = kwargs.get("import_id")
    files = [("files", cv_builder(name, body)) for name, body in specs]
    data = {"import_id": import_id} if import_id else None
    resp = client.post(
        f"/api/jobs/{job_id}/candidates/import",
        files=files,
        data=data,
    )
    assert resp.status_code == 202, resp.text
    return resp.json()


def upload_cvs_and_wait(client, job_id, cv_builder, *specs, **kwargs) -> dict:
    """Upload a batch and wait for its documents to reach a terminal state.
    Returns the final import status dict."""
    resp = upload_cvs(client, job_id, cv_builder, *specs, **kwargs)
    return wait_for_import(client, job_id, resp["import_id"], **kwargs)


def wait_for_import(client, job_id, import_id, timeout=10.0, **_) -> dict:
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        last = client.get(f"/api/jobs/{job_id}/imports/{import_id}").json()
        if last["status"] in ("completed", "partially_failed", "failed"):
            return last
        time.sleep(0.02)
    raise AssertionError(f"import {import_id} did not finish: {last}")


SENIOR_BACKEND = """John Doe
Senior Python Engineer

Summary
10 years building distributed backend systems at scale.

Skills
Python, Django, FastAPI, SQL, PostgreSQL, Docker, Kubernetes, AWS, Redis,
Machine Learning, Kubernetes.

Experience
Led the platform team designing microservices in Python. Built real-time
pipelines with Kafka and Redis. Designed CI/CD with Jenkins and Docker.

Education
Master of Science in Computer Science

Certifications
AWS Certified Solutions Architect
"""

JUNIOR_BACKEND = """Alice Smith
Junior Developer

Summary
2 years experience with web development.

Skills
Python, Django, SQL, HTML, CSS, JavaScript.

Experience
Worked on internal tools and CRUD APIs with Django.

Education
Bachelor of Science in Computer Science
"""

FRONTEND_ONLY = """Bob Jones
Frontend Engineer

Summary
5 years of React and UI work.

Skills
React, JavaScript, TypeScript, HTML, CSS, Tailwind, Figma.

Experience
Built design systems and customer-facing dashboards.

Education
Bachelor of Science in Information Technology
"""

BACKEND_JD = """Senior Backend Engineer

Requirements
- Python
- Docker
- AWS
- PostgreSQL
- 5+ years of experience

Nice to have
- Kubernetes
- Machine Learning

Responsibilities
Design and operate highly available backend services.
"""
