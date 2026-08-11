from __future__ import annotations

from uuid import uuid4

from app.config import settings
from tests.conftest import (
    BACKEND_JD,
    FRONTEND_ONLY,
    JUNIOR_BACKEND,
    SENIOR_BACKEND,
    create_job,
    upload_cvs_and_wait,
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
    job_id = create_job(client)

    resp = upload_cvs_and_wait(client, job_id, cv_builder, ("john.txt", SENIOR_BACKEND), ("alice.txt", JUNIOR_BACKEND))
    assert resp["status"] == "completed"

    body = client.get(f"/api/jobs/{job_id}/cvs").json()
    results = body["results"]
    assert len(results) == 2
    assert all(r["status"] == "completed" for r in results)
    assert all(r["source"] == "rules" for r in results)  # no LLM key in tests
    names = {r["candidate_name"] for r in results}
    assert "John Doe" in names


def test_rank_orders_candidates_with_reasoning(client, cv_builder):
    job_id = create_job(client)

    upload_cvs_and_wait(
        client,
        job_id,
        cv_builder,
        ("john.txt", SENIOR_BACKEND),
        ("alice.txt", JUNIOR_BACKEND),
        ("bob.txt", FRONTEND_ONLY),
    )

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
    upload_cvs_and_wait(client, job_id, cv_builder, ("alice.txt", JUNIOR_BACKEND))
    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 422


def test_get_rankings_persisted(client, cv_builder):
    job_id = create_job(client)
    upload_cvs_and_wait(client, job_id, cv_builder, ("john.txt", SENIOR_BACKEND))
    client.post(f"/api/jobs/{job_id}/rank")

    resp = client.get(f"/api/jobs/{job_id}/rankings")
    assert resp.status_code == 200
    assert resp.json()["count"] == 1
    assert resp.json()["results"][0]["candidate_name"] == "John Doe"


def test_rank_single_cv_persists_rank(client, cv_builder):
    job_id = create_job(client)
    cv_id = _upload_cv(client, job_id, cv_builder, "john.txt", SENIOR_BACKEND)

    resp = client.post(f"/api/jobs/{job_id}/cvs/{cv_id}/rank")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["source"] == "rules"
    result = body["result"]
    assert result["status"] == "ranked"
    assert result["cv_id"] == cv_id
    assert result["overall_score"] is not None
    assert result["explanation"]
    assert result["ranked_by"] == "rules"

    ranked = client.get(f"/api/jobs/{job_id}/rankings").json()["results"]
    assert len(ranked) == 1
    assert ranked[0]["cv_id"] == cv_id
    assert ranked[0]["ranked_by"] == "rules"


def test_rank_single_cv_unknown_404(client, cv_builder):
    job_id = create_job(client)
    resp = client.post(f"/api/jobs/{job_id}/cvs/{uuid4()}/rank")
    assert resp.status_code == 404

    resp = client.post(
        f"/api/jobs/00000000-0000-0000-0000-000000000000/cvs/{uuid4()}/rank"
    )
    assert resp.status_code == 404


def test_bulk_rank_reranks_already_ranked_cvs(client, cv_builder):
    job_id = create_job(client)
    cv_id = _upload_cv(client, job_id, cv_builder, "john.txt", SENIOR_BACKEND)
    _upload_cv(client, job_id, cv_builder, "alice.txt", JUNIOR_BACKEND)

    client.post(f"/api/jobs/{job_id}/cvs/{cv_id}/rank")

    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 200, resp.text
    # bulk rank re-scores everything that has finished processing
    assert resp.json()["count"] == 2

    ranked = client.get(f"/api/jobs/{job_id}/rankings").json()["results"]
    assert len(ranked) == 2  # both now ranked


def test_bulk_rank_rejects_when_no_candidates_ready(client, cv_builder):
    import asyncio

    from app.database.db_client import DbClient

    job_id = create_job(client)
    cv_id = _upload_cv(client, job_id, cv_builder, "alice.txt", JUNIOR_BACKEND)

    # force the CV back to an in-progress state so nothing is ready to rank
    asyncio.run(
        DbClient().execute(
            "UPDATE cvs SET status = 'uploaded' WHERE id = ?",
            (cv_id,),
        )
    )

    resp = client.post(f"/api/jobs/{job_id}/rank")
    assert resp.status_code == 422, resp.text
    assert resp.json()["detail"] == "no_candidates_ready"


def test_list_jobs_includes_cv_count(client, cv_builder):
    job_id = create_job(client)

    resp = client.get("/api/jobs")
    assert resp.status_code == 200
    assert resp.json()["jobs"][0]["cv_count"] == 0

    upload_cvs_and_wait(client, job_id, cv_builder, ("john.txt", SENIOR_BACKEND))

    resp = client.get("/api/jobs")
    assert resp.json()["jobs"][0]["cv_count"] == 1


def test_unknown_job_404(client):
    assert client.get("/api/jobs/00000000-0000-0000-0000-000000000000").status_code == 404
    assert client.post("/api/jobs/00000000-0000-0000-0000-000000000000/rank").status_code == 404


def _create_jobs(client, count: int) -> list[str]:
    ids = []
    for i in range(count):
        resp = client.post(
            "/api/jobs",
            data={"title": f"Job {i}", "description": BACKEND_JD},
        )
        ids.append(resp.json()["job"]["job_id"])
    return ids


def test_list_jobs_default_page_and_meta(client):
    _create_jobs(client, 3)

    resp = client.get("/api/jobs")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["jobs"]) == 3
    assert body["count"] == 3
    assert body["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_list_jobs_paginates_and_reports_has_more(client):
    _create_jobs(client, 5)

    first = client.get("/api/jobs", params={"page": 1, "limit": 2})
    assert first.status_code == 200
    assert len(first.json()["jobs"]) == 2
    assert first.json()["meta"] == {"page": 1, "limit": 2, "has_more": True}

    last = client.get("/api/jobs", params={"page": 3, "limit": 2})
    assert last.status_code == 200
    assert len(last.json()["jobs"]) == 1
    assert last.json()["meta"] == {"page": 3, "limit": 2, "has_more": False}


def test_list_jobs_page_beyond_end_returns_empty(client):
    _create_jobs(client, 2)

    resp = client.get("/api/jobs", params={"page": 5, "limit": 2})
    assert resp.status_code == 200
    assert resp.json()["jobs"] == []
    assert resp.json()["meta"] == {"page": 5, "limit": 2, "has_more": False}


def test_list_jobs_orders_newest_first_across_pages(client):
    ids = _create_jobs(client, 3)

    page = client.get("/api/jobs", params={"limit": 2}).json()["jobs"]
    assert [j["job_id"] for j in page] == [ids[2], ids[1]]

    next_page = client.get("/api/jobs", params={"page": 2, "limit": 2}).json()["jobs"]
    assert [j["job_id"] for j in next_page] == [ids[0]]


def test_list_jobs_invalid_pagination_params(client):
    assert client.get("/api/jobs", params={"page": 0}).status_code == 422
    assert client.get("/api/jobs", params={"limit": 0}).status_code == 422
    assert client.get("/api/jobs", params={"limit": 101}).status_code == 422


def test_search_jobs_filters_by_title(client):
    _create_jobs(client, 3)

    resp = client.get("/api/jobs/search", params={"keyword": "Job 1"})
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["jobs"]) == 1
    assert body["jobs"][0]["title"] == "Job 1"
    assert body["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_search_jobs_filters_case_insensitively(client):
    _create_jobs(client, 2)

    resp = client.get("/api/jobs/search", params={"keyword": "job 0"})
    assert resp.status_code == 200
    assert [j["title"] for j in resp.json()["jobs"]] == ["Job 0"]


def test_search_jobs_matches_description(client):
    client.post(
        "/api/jobs",
        data={"title": "Data Platform", "description": "Builds Kafka pipelines"},
    )
    client.post(
        "/api/jobs",
        data={"title": "Web UI", "description": "React dashboards"},
    )

    resp = client.get("/api/jobs/search", params={"keyword": "kafka"})
    body = resp.json()
    assert len(body["jobs"]) == 1
    assert body["jobs"][0]["title"] == "Data Platform"


def test_search_jobs_no_match_returns_empty(client):
    _create_jobs(client, 2)

    resp = client.get("/api/jobs/search", params={"keyword": "zzz-no-such-job"})
    assert resp.status_code == 200
    assert resp.json()["jobs"] == []
    assert resp.json()["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_search_jobs_requires_keyword(client):
    assert client.get("/api/jobs/search").status_code == 422


def test_search_jobs_empty_keyword_lists_all(client):
    _create_jobs(client, 2)

    resp = client.get("/api/jobs/search", params={"keyword": ""})
    assert resp.status_code == 200
    assert len(resp.json()["jobs"]) == 2
    assert resp.json()["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_search_jobs_paginates(client):
    for i in range(5):
        client.post(
            "/api/jobs",
            data={"title": f"Engineer {i}", "description": BACKEND_JD},
        )

    first = client.get(
        "/api/jobs/search", params={"keyword": "Engineer", "page": 1, "limit": 2}
    )
    assert first.status_code == 200
    assert len(first.json()["jobs"]) == 2
    assert first.json()["meta"] == {"page": 1, "limit": 2, "has_more": True}

    last = client.get(
        "/api/jobs/search", params={"keyword": "Engineer", "page": 3, "limit": 2}
    )
    assert len(last.json()["jobs"]) == 1
    assert last.json()["meta"] == {"page": 3, "limit": 2, "has_more": False}


def test_search_jobs_does_not_shadow_job_by_id(client):
    job_id = create_job(client)

    assert client.get(f"/api/jobs/{job_id}").status_code == 200
    # /jobs/search is its own route, not a job id lookup
    assert client.get("/api/jobs/search").status_code == 422


def test_search_candidates_matches_name_across_jobs(client, cv_builder):
    job_a = create_job(client)
    job_b = create_job(client)
    _upload_cv(client, job_a, cv_builder, "john.txt", SENIOR_BACKEND)
    _upload_cv(client, job_b, cv_builder, "alice.txt", JUNIOR_BACKEND)

    resp = client.get("/api/candidates/search", params={"keyword": "John"})
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["candidates"]) == 1
    assert body["candidates"][0]["candidate_name"] == "John Doe"
    assert body["candidates"][0]["job_id"] == job_a
    assert body["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_search_candidates_matches_skills_case_insensitively(client, cv_builder):
    job_id = create_job(client)
    _upload_cv(client, job_id, cv_builder, "alice.txt", JUNIOR_BACKEND)
    _upload_cv(client, job_id, cv_builder, "bob.txt", FRONTEND_ONLY)

    resp = client.get("/api/candidates/search", params={"keyword": "react"})
    assert resp.status_code == 200
    names = [c["candidate_name"] for c in resp.json()["candidates"]]
    assert names == ["Bob Jones"]


def test_search_candidates_matches_file_name(client, cv_builder):
    job_id = create_job(client)
    _upload_cv(client, job_id, cv_builder, "resume_mira.txt", SENIOR_BACKEND)

    resp = client.get("/api/candidates/search", params={"keyword": "mira"})
    assert resp.status_code == 200
    assert len(resp.json()["candidates"]) == 1


def test_search_candidates_no_match_returns_empty(client, cv_builder):
    job_id = create_job(client)
    _upload_cv(client, job_id, cv_builder, "alice.txt", JUNIOR_BACKEND)

    resp = client.get(
        "/api/candidates/search", params={"keyword": "zzz-no-such-candidate"}
    )
    assert resp.status_code == 200
    assert resp.json()["candidates"] == []
    assert resp.json()["meta"] == {"page": 1, "limit": 20, "has_more": False}


def test_search_candidates_requires_keyword(client):
    assert client.get("/api/candidates/search").status_code == 422


def test_search_candidates_paginates(client, cv_builder):
    job_id = create_job(client)
    for i in range(5):
        _upload_cv(
            client,
            job_id,
            cv_builder,
            f"cand_{i}.txt",
            f"Dev {i}\n\nSkills\nPython, Flask\n",
        )

    first = client.get(
        "/api/candidates/search", params={"keyword": "Python", "page": 1, "limit": 2}
    )
    assert first.status_code == 200
    assert len(first.json()["candidates"]) == 2
    assert first.json()["meta"] == {"page": 1, "limit": 2, "has_more": True}

    last = client.get(
        "/api/candidates/search", params={"keyword": "Python", "page": 3, "limit": 2}
    )
    assert len(last.json()["candidates"]) == 1
    assert last.json()["meta"] == {"page": 3, "limit": 2, "has_more": False}


def _upload_cv(client, job_id, cv_builder, name, body):
    resp = upload_cvs_and_wait(client, job_id, cv_builder, (name, body))
    assert resp["status"] == "completed"
    cvs = client.get(f"/api/jobs/{job_id}/cvs").json()["results"]
    return cvs[-1]["cv_id"]


def test_delete_cv_removes_row_and_file(client, cv_builder):
    job_id = create_job(client)
    cv_id = _upload_cv(client, job_id, cv_builder, "john.txt", SENIOR_BACKEND)

    assert len(list(settings.upload_dir.glob("*"))) == 1

    resp = client.delete(f"/api/jobs/{job_id}/cvs/{cv_id}")
    assert resp.status_code == 200
    assert resp.json()["deleted"] is True

    assert list(settings.upload_dir.glob("*")) == []
    assert client.get(f"/api/jobs/{job_id}/cvs").json()["results"] == []


def test_delete_cv_unknown_404(client, cv_builder):
    job_id = create_job(client)
    cv_id = _upload_cv(client, job_id, cv_builder, "john.txt", SENIOR_BACKEND)

    assert client.delete(f"/api/jobs/{job_id}/cvs/{uuid4()}").status_code == 404
    assert client.delete(f"/api/jobs/{job_id}/cvs/{cv_id}").status_code == 200
    assert client.delete(f"/api/jobs/{job_id}/cvs/{cv_id}").status_code == 404
    assert (
        client.delete("/api/jobs/00000000-0000-0000-0000-000000000000/cvs/x").status_code
        == 404
    )


def test_delete_job_cascades_cvs_and_files(client, cv_builder):
    job_id = create_job(client)
    _upload_cv(client, job_id, cv_builder, "john.txt", SENIOR_BACKEND)
    _upload_cv(client, job_id, cv_builder, "alice.txt", JUNIOR_BACKEND)
    assert len(list(settings.upload_dir.glob("*"))) == 2

    resp = client.delete(f"/api/jobs/{job_id}")
    assert resp.status_code == 200
    assert resp.json()["deleted"] is True

    assert list(settings.upload_dir.glob("*")) == []
    assert client.get(f"/api/jobs/{job_id}").status_code == 404
    jobs = client.get("/api/jobs").json()["jobs"]
    assert all(j["job_id"] != job_id for j in jobs)


def test_delete_job_unknown_404(client):
    assert (
        client.delete("/api/jobs/00000000-0000-0000-0000-000000000000").status_code
        == 404
    )
