from __future__ import annotations

"""Unit tests for the copilot's deterministic query router.

Regression coverage for the chat-card bug: listing requests phrased as
"show me the candidate" used to be misrouted to ``candidate_detail`` (the
single-Gemini reasoning path, which returns no structured cards), so the app
showed plain text instead of tappable candidate tiles.
"""

from app.chat._router import QueryRoute, QueryRouter


def route(question: str) -> QueryRoute:
    return QueryRouter.route(question)


def test_show_me_the_candidate_is_a_list_request():
    # "the candidate" must be treated as a list/search request, not as a
    # reference to one specific candidate, so the deterministic path returns
    # candidate cards the chat UI can render.
    assert route("show me the candidate").mode == "deterministic"
    assert route("show me the candidate").intent == "candidate_search"


def test_list_candidate_phrases_route_to_search():
    for question in (
        "show me the candidates",
        "show me the candidates for the job",
        "who applied",
        "list candidates",
        "show candidates",
    ):
        assert route(question).intent == "candidate_search"
        assert route(question).mode == "deterministic"


def test_demonstrative_reference_routes_to_detail():
    assert route("tell me about this candidate").intent == "candidate_detail"
    assert route("tell me about this candidate").mode == "rag_reasoning"
    assert route("what about that applicant").intent == "candidate_detail"


def test_cv_id_routes_to_detail():
    assert route("what can you tell me about cv-abc123-def").intent == "candidate_detail"


def test_ranking_request_still_routes_to_ranking():
    assert route("rank the candidates").intent == "candidate_ranking"
    assert route("rank the candidates").mode == "deterministic"