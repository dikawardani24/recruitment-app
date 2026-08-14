from __future__ import annotations

"""API regression tests for the copilot chat.

Regression coverage for the chat-card bug: "show me the candidate" (singular)
was routed to the LLM reasoning path (which returns no structured cards), so the
app rendered plain text instead of tappable candidate tiles. It must route to the
deterministic path and return a candidate `cards` payload.
"""

from tests.conftest import JUNIOR_BACKEND, SENIOR_BACKEND, create_job, upload_cvs_and_wait


def _chat(client, question: str, **overrides) -> dict:
    payload = {"question": question, "api_key": "test-key"}
    payload.update(overrides)
    resp = client.post("/api/chat", json=payload)
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_chat_show_me_the_candidate_returns_candidate_cards(client, cv_builder):
    job_id = create_job(client)
    upload_cvs_and_wait(
        client, job_id, cv_builder, ("john.txt", SENIOR_BACKEND), ("alice.txt", JUNIOR_BACKEND)
    )

    body = _chat(client, "show me the candidate")

    cards = body.get("cards", [])
    assert len(cards) == 1
    group = cards[0]
    assert group["type"] == "candidate"
    cv_ids = {item["cv_id"] for item in group["items"]}
    assert len(cv_ids) == 2
    assert all(item["name"] for item in group["items"])


def test_chat_show_me_the_candidates_returns_candidate_cards(client, cv_builder):
    job_id = create_job(client)
    upload_cvs_and_wait(client, job_id, cv_builder, ("john.txt", SENIOR_BACKEND))

    body = _chat(client, "show me the candidates")

    cards = body.get("cards", [])
    assert len(cards) == 1
    assert cards[0]["type"] == "candidate"
    assert cards[0]["items"][0]["name"] == "John Doe"


def test_chat_show_me_the_candidate_with_no_applicants_returns_no_cards(client):
    job_id = create_job(client)

    body = _chat(client, "show me the candidate")

    assert "no applicants" in body["answer"]
    assert body.get("cards") == []
