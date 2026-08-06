from __future__ import annotations

from tests.conftest import (
    BACKEND_JD,
    FRONTEND_ONLY,
    JUNIOR_BACKEND,
    SENIOR_BACKEND,
)


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_create_job_from_text(client):
    resp = client.post(
        "/api/jobs",
        data={"title": "Senior Backend Engineer", "description": BACKEND_JD},
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()["job"]
    assert body["title"] == "Senior Backend Engineer"
    assert body["requirements"] is not None
    req = body["requirements"]
    assert "python" in req["required_skills"]
    assert req["min_years"] == 5.0


def test_create_job_title_required(client):
    resp = client.post("/api/jobs", data={"title": "   "})
    assert resp.status_code == 422


def test_create_job_from_uploaded_jd_file(client, cv_builder):
    name, content, mime = cv_builder("job.txt", BACKEND_JD)
    resp = client.post(
        "/api/jobs",
        data={"title": "Backend"},
        files={"jd_file": (name, content, mime)},
    )
    assert resp.status_code == 201, resp.text
    job = resp.json()["job"]
    assert BACKEND_JD.strip() in job["description"]
    assert job["requirements"]["min_years"] == 5.0


def test_upload_multiple_cvs(client, cv_builder):
    resp = client.post(
        "/api/jobs",
        data={"title": "Senior Backend Engineer", "description": BACKEND_JD},
    )
    job_id = resp.json()["job"]["job_id"]

    files = [
        ("files", cv_builder("john.txt", SENIOR_BACKEND)),
        ("files", cv_builder("alice.txt", JUNIOR_BACKEND)),
    ]
    resp = client.post(f"/api/jobs/{job_id}/cvs", files=files)
    assert resp.status_code == 201, resp.text
    results = resp.json()["results"]
    assert len(results) == 2
    assert all(r["status"] == "parsed" for r in results)
    assert all(r["source"] == "rules" for r in results)  # no LLM key in tests
    names = {r["candidate_name"] for r in results}
    assert "John Doe" in names


def test_rank_orders_candidates_with_reasoning(client, cv_builder):
    resp = client.post(
        "/api/jobs",
        data={"title": "Senior Backend Engineer", "description": BACKEND_JD},
    )
    job_id = resp.json()["job"]["job_id"]

    files = [
        ("files", cv_builder("john.txt", SENIOR_BACKEND)),
        ("files", cv_builder("alice.txt", JUNIOR_BACKEND)),
        ("files", cv_builder("bob.txt", FRONTEND_ONLY)),
    ]
    assert client.post(f"/api/jobs/{job_id}/cvs", files=files).status_code == 201

    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["count"] == 3
    assert body["source"] == "rules"  # no LLM key configured in tests

    results = body["results"]
    scores = [r["overall_score"] for r in results]
    assert scores == sorted(scores, reverse=True)

    top = results[0]
    assert top["candidate_name"] == "John Doe"
    assert top["overall_score"] > results[2]["overall_score"]
    assert top["explanation"]
    assert top["strengths"]
    assert results[2]["weaknesses"]
    assert "python" in {s.lower() for s in top["skills"]}

    names = {r["candidate_name"] for r in results}
    assert names == {"John Doe", "Alice Smith", "Bob Jones"}


def test_rank_without_description_returns_422(client, cv_builder):
    resp = client.post("/api/jobs", data={"title": "No JD"})
    job_id = resp.json()["job"]["job_id"]
    name, content, mime = cv_builder("alice.txt", JUNIOR_BACKEND)
    client.post(f"/api/jobs/{job_id}/cvs", files=[("files", (name, content, mime))])
    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 422


def test_get_rankings_persisted(client, cv_builder):
    resp = client.post(
        "/api/jobs",
        data={"title": "Senior Backend Engineer", "description": BACKEND_JD},
    )
    job_id = resp.json()["job"]["job_id"]
    name, content, mime = cv_builder("john.txt", SENIOR_BACKEND)
    client.post(f"/api/jobs/{job_id}/cvs", files=[("files", (name, content, mime))])
    client.post(f"/api/jobs/{job_id}/rank")

    resp = client.get(f"/api/jobs/{job_id}/rankings")
    assert resp.status_code == 200
    assert resp.json()["count"] == 1
    assert resp.json()["results"][0]["candidate_name"] == "John Doe"


def test_list_jobs_includes_cv_count(client, cv_builder):
    resp = client.post(
        "/api/jobs",
        data={"title": "Senior Backend Engineer", "description": BACKEND_JD},
    )
    job_id = resp.json()["job"]["job_id"]

    resp = client.get("/api/jobs")
    assert resp.status_code == 200
    assert resp.json()["jobs"][0]["cv_count"] == 0

    name, content, mime = cv_builder("john.txt", SENIOR_BACKEND)
    client.post(f"/api/jobs/{job_id}/cvs", files=[("files", (name, content, mime))])

    resp = client.get("/api/jobs")
    assert resp.json()["jobs"][0]["cv_count"] == 1


def test_unknown_job_404(client):
    assert client.get("/api/jobs/00000000-0000-0000-0000-000000000000").status_code == 404
    assert client.post("/api/jobs/00000000-0000-0000-0000-000000000000/rank").status_code == 404
