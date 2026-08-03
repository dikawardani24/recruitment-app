from __future__ import annotations

import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import db
from app.config import settings


@pytest.fixture()
def client(tmp_path: Path):
    settings.db_path = tmp_path / "test.db"
    settings.upload_dir = tmp_path / "uploads"
    settings.llm_api_key = None
    settings.ensure_dirs()

    import asyncio

    asyncio.run(db.init_db())

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
