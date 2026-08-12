from __future__ import annotations

import hashlib
import json
import math
from datetime import UTC, datetime

import pytest

from app.config import Settings
from app.chat import ChatClient, ChatError, QueryRouter, ToolCall, ToolError, ToolRegistry
from app.domain.candidate import Candidate
from app.domain.job import Job
from app.domain.page import Page
from app.rag._chunker import chunk_candidate, chunk_job
from app.rag._indexer import EmbeddingIndexer
from app.rag._qdrant import Point, ScoredHit
from app.rag._retriever import retrieve_evidence
from app.usecase.ask import Ask
from app.usecase.reindex_embeddings import ReindexEmbeddings
from app.usecase.save_job import SaveJob
from app.usecase.semantic_search import SemanticSearch
from app.chat import QueryRouter

DIM = 384


def _settings() -> Settings:
    s = Settings()
    s.rag_enabled = True
    s.rag_embedding_model = "test-model"
    s.rag_embedding_dim = DIM
    s.rag_embedding_version = "test:v1"
    return s


def _vector(text: str) -> list[float]:
    """Deterministic bag-of-words vector: shared tokens => high cosine."""
    v = [0.0] * DIM
    for token in text.lower().split():
        idx = int(hashlib.md5(token.encode()).hexdigest(), 16) % DIM
        v[idx] += 1.0
    norm = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / norm for x in v]


def _cosine(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


class FakeEmbedder:
    async def embed(self, texts: list[str]) -> list[list[float]]:
        return [_vector(t) for t in texts]


class FakeStore:
    def __init__(self):
        self.points: dict[str, Point] = {}

    async def upsert(self, points: list[Point]) -> None:
        for point in points:
            self.points[point.id] = point

    async def delete(self, must: list[tuple[str, object]]) -> None:
        for pid in [pid for pid, p in self.points.items() if self._matches(p, must)]:
            self.points.pop(pid)

    async def count(self, must: list[tuple[str, object]]) -> int:
        return sum(1 for p in self.points.values() if self._matches(p, must))

    async def search(self, vector: list[float], must: list[tuple[str, object]], limit: int) -> list[ScoredHit]:
        scored = []
        for p in self.points.values():
            if self._matches(p, must):
                scored.append(ScoredHit(score=_cosine(p.vector, vector), payload=p.payload))
        scored.sort(key=lambda s: s.score, reverse=True)
        return scored[:limit]

    def close(self) -> None:
        pass

    def _matches(self, point: Point, must: list[tuple[str, object]]) -> bool:
        return all(point.payload.get(key) == value for key, value in must)


class FakeJobRepo:
    def __init__(self, jobs: list[Job] | None = None):
        self.jobs: dict[str, Job] = {job.id: job for job in (jobs or [])}

    async def save(self, job: Job) -> None:
        self.jobs[job.id] = job

    async def get_by_id(self, job_id: str) -> Job | None:
        return self.jobs.get(job_id)

    async def get_job(self, page: int, page_size: int) -> Page:
        data = list(self.jobs.values())
        start = (page - 1) * page_size
        slice_ = data[start : start + page_size]
        return Page(page=page, page_size=page_size, data=slice_, last_page=start + page_size >= len(data))


class FakeCvRepo:
    def __init__(self, cvs: list[Candidate] | None = None):
        self.cvs: dict[str, Candidate] = {cv.id: cv for cv in (cvs or [])}

    async def find_by_job(self, job_id: str) -> list[Candidate]:
        return [cv for cv in self.cvs.values() if cv.job_id == job_id]

    async def find_by_id(self, job_id: str, cv_id: str) -> Candidate | None:
        cv = self.cvs.get(cv_id)
        return cv if cv and cv.job_id == job_id else None

    async def count_by_job_ids(self, job_ids: list[str]) -> dict[str, int]:
        return {
            job_id: sum(1 for cv in self.cvs.values() if cv.job_id == job_id)
            for job_id in job_ids
        }


def _job(job_id: str, title: str, description: str = "", req: dict | None = None) -> Job:
    now = datetime.now(UTC)
    return Job(
        title=title,
        desc=description,
        req=json.dumps(req) if req else None,
        status="open",
        created_at=now,
        updated_at=now,
        id=job_id,
    )


def _candidate(cv_id: str, job_id: str, name: str, skills: list[str]) -> Candidate:
    return Candidate(
        id=cv_id,
        job_id=job_id,
        file_name=f"{cv_id}.txt",
        storage_path=f"/tmp/{cv_id}.txt",
        status="completed",
        candidate_name=name,
        profile_text=f"{name} builds things with {' and '.join(skills)}.",
        skills=skills,
        years_experience=5.0,
        education="BSc Computer Science",
        certifications=["AWS"],
    )


def test_chunk_candidate_sections():
    candidate = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    sections = [chunk.section for chunk in chunk_candidate(candidate)]
    assert "summary" in sections
    assert "skills" in sections
    assert "education" in sections
    assert "certifications" in sections


def test_chunk_candidate_windows_long_profile():
    candidate = _candidate("cv-1", "job-1", "Jane", ["Flutter"])
    candidate.profile_text = "word " * 2000
    chunks = chunk_candidate(candidate)
    assert any(chunk.section == "experience" for chunk in chunks)
    assert all(len(chunk.content) <= 700 for chunk in chunks)


def test_chunk_job_requirements():
    req = {
        "required_skills": ["Python", "Docker"],
        "preferred_skills": ["Kubernetes"],
        "responsibilities": ["Run services", "Fix bugs"],
        "education": "BSc",
        "min_years": 5,
    }
    job = _job("job-1", "Backend Engineer", description="Build services", req=req)
    sections = {chunk.section: chunk.content for chunk in chunk_job(job)}
    assert sections["description"].startswith("Backend Engineer")
    assert "Python" in sections["required_skills"]
    assert "Kubernetes" in sections["preferred_skills"]
    assert "Fix bugs" in sections["responsibilities"]
    assert "BSc" in sections["qualifications"]


def test_chunk_job_metadata_includes_dates():
    created = datetime(2026, 8, 6, 14, 5, 0, tzinfo=UTC)
    job = Job(
        title="Flutter Dev",
        desc="Build the app",
        req=None,
        status="open",
        created_at=created,
        updated_at=created,
        id="job-1",
    )
    sections = {chunk.section: chunk.content for chunk in chunk_job(job)}
    assert "Flutter Dev" in sections["metadata"]
    assert "Status: open" in sections["metadata"]
    assert "Created at: 2026-08-06 14:05:00" in sections["metadata"]
    assert "Last updated at: 2026-08-06 14:05:00" in sections["metadata"]


async def test_semantic_search_disabled_returns_enabled_false():
    use_case = SemanticSearch(None, FakeJobRepo(), FakeCvRepo())
    result = await use_case.execute("flutter", "candidate")
    assert result["enabled"] is False
    assert result["results"] == []


async def test_semantic_search_candidate_roundtrip():
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    candidate = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())
    job_repo = FakeJobRepo([job])
    cv_repo = FakeCvRepo([candidate])

    assert await indexer.index_job(job) > 0
    assert await indexer.index_candidate(candidate) > 0

    result = await SemanticSearch(indexer, job_repo, cv_repo).execute(
        "flutter developer", "candidate", top_k=5
    )
    assert result["enabled"] is True
    assert result["count"] == 1
    top = result["results"][0]
    assert top["entity_type"] == "candidate"
    assert top["id"] == "cv-1"
    assert top["score"] > 0.0
    assert top["sections"][0]["section"] == "summary"


async def test_semantic_search_job_roundtrip():
    job = _job("job-1", "Backend Engineer", description="Python and PostgreSQL services")
    candidate = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter"])
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())
    job_repo = FakeJobRepo([job])
    cv_repo = FakeCvRepo([candidate])

    await indexer.index_job(job)
    await indexer.index_candidate(candidate)

    result = await SemanticSearch(indexer, job_repo, cv_repo).execute("python postgres", "job", top_k=5)
    assert result["count"] == 1
    assert result["results"][0]["id"] == "job-1"
    assert result["results"][0]["job"]["title"] == "Backend Engineer"


async def test_query_uses_bge_prefix():
    job = _job("job-1", "Backend Engineer", description="Python and PostgreSQL services")
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())
    await indexer.index_job(job)
    raw = (await FakeEmbedder().embed(["python postgres"]))[0]
    prefixed = await indexer.embed_query("python postgres")
    assert _cosine(raw, prefixed) < 1.0


async def test_reindex_builds_and_is_idempotent():
    job = _job("job-1", "Backend Engineer", description="Python and PostgreSQL services")
    candidate = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter"])
    job_repo = FakeJobRepo([job])
    cv_repo = FakeCvRepo([candidate])
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())

    reindex = ReindexEmbeddings(indexer, job_repo, cv_repo)
    first = await reindex.execute()
    assert first["enabled"] is True
    assert first["indexed_jobs"] == 1
    assert first["indexed_candidates"] == 1
    count_after_first = await indexer.count_indexed()

    second = await reindex.execute()
    assert second["indexed_jobs"] == 1
    assert await indexer.count_indexed() == count_after_first


async def test_reindex_single_job():
    job1 = _job("job-1", "Backend Engineer", description="Python services")
    job2 = _job("job-2", "Frontend Engineer", description="React UI")
    job_repo = FakeJobRepo([job1, job2])
    cv_repo = FakeCvRepo([])
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())

    result = await ReindexEmbeddings(indexer, job_repo, cv_repo).execute(job_id="job-2")
    assert result["indexed_jobs"] == 1
    assert await indexer.count_indexed() > 0
    hits = await indexer.search("react", "job", top_k=5)
    assert hits[0].payload["entity_id"] == "job-2"


async def test_delete_entity_removes_points():
    job = _job("job-1", "Backend Engineer", description="Python services")
    indexer = EmbeddingIndexer(_settings(), FakeEmbedder(), FakeStore())
    await indexer.index_job(job)
    assert await indexer.count_indexed() > 0
    await indexer.delete_entity("job", "job-1")
    assert await indexer.count_indexed() == 0


async def test_save_job_indexes_when_rag_enabled():
    class RecordingIndexer:
        enabled = True

        def __init__(self):
            self.indexed: list[Job] = []

        async def index_job(self, job: Job) -> int:
            self.indexed.append(job)
            return 1

    repo = FakeJobRepo()
    indexer = RecordingIndexer()
    use_case = SaveJob(repo, indexer)
    result = await use_case.execute(title="Backend Engineer", description="Python services")
    assert len(indexer.indexed) == 1
    assert indexer.indexed[0].id == result["job"]["job_id"]


async def test_save_job_without_indexer_works():
    repo = FakeJobRepo()
    use_case = SaveJob(repo, None)
    result = await use_case.execute(title="Backend Engineer", description="Python services")
    assert result["job"]["title"] == "Backend Engineer"


def test_api_semantic_search_disabled(client):
    resp = client.post(
        "/api/search/semantic",
        json={"query": "flutter", "entity": "candidate", "top_k": 5},
    )
    assert resp.status_code == 200
    assert resp.json()["enabled"] is False
    assert resp.json()["results"] == []


def test_api_reindex_disabled(client):
    resp = client.post("/api/search/reindex", json={})
    assert resp.status_code == 200
    assert resp.json()["enabled"] is False


# --- Chat copilot (recruiter Q&A) ---


class FakeChatClient:
    def __init__(self):
        self.calls: list[tuple[str, str]] = []

    async def complete(self, system: str, user: str, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        self.calls.append((system, user))
        return "Jane Doe matches the Flutter role [1]."


class FakeStreamingChatClient(FakeChatClient):
    def __init__(self, items):
        super().__init__()
        self.items = items
        self.tool_calls: list[tuple[str, str]] = []

    async def complete_stream(self, system, user, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        self.calls.append((system, user))
        for item in self.items:
            if isinstance(item, ToolCall):
                await execute_tool(item.name, item.arguments)
                self.tool_calls.append((item.name, item.arguments))
            yield item


class ExplodingChatClient:
    """Package-only fake: raises if Gemini is ever called (used to prove that
    deterministic queries complete with ZERO Gemini requests)."""

    async def complete(self, system, user, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        raise AssertionError("Gemini should not have been called")

    async def complete_stream(self, system, user, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        raise AssertionError("Gemini should not have been called")
        yield None  # pragma: no cover


class FailingChatClient:
    def __init__(self, error: str):
        self.error = error

    async def complete(self, system, user, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        raise ChatError(self.error)

    async def complete_stream(self, system, user, tools=None, execute_tool=None, model_id=None, runtime_api_key=None):
        raise ChatError(self.error)
        yield None  # pragma: no cover


def _chat_settings() -> Settings:
    s = _settings()
    s.llm_api_key = "test-key"
    return s


async def test_ask_disabled_when_no_llm_key():
    s = _settings()
    s.llm_api_key = None
    s.openrouter_api_key = None
    result = await Ask(s, FakeChatClient(), None).execute("who is best?")
    assert result["configured"] is False
    assert "not configured" in result["answer"]


async def test_ask_enabled_by_client_api_key_overrides_server_default():
    """A client-supplied api_key enables chat even when no server key is set,
    and falls back to the server key when the client key is omitted."""
    s = _settings()
    s.llm_api_key = None
    s.openrouter_api_key = None

    # No client key -> still not configured (falls back to default = none).
    result = await Ask(s, FakeChatClient(), None).execute("who is best?")
    assert result["configured"] is False

    # Client supplies its own key -> chat becomes configured.
    result = await Ask(s, FakeChatClient(), None).execute(
        "who is best?", api_key="client-key"
    )
    assert result["configured"] is True
    assert result["answer"] == "Jane Doe matches the Flutter role [1]."


async def test_chat_client_resolves_openrouter_model_from_client_key():
    """A client-supplied OpenRouter key enables an OpenRouter model even when
    the server has no keys configured at startup."""
    s = _settings()
    s.llm_api_key = None
    s.openrouter_api_key = None

    client = ChatClient(s)
    option = client._resolve(
        "openrouter:qwen/qwen-2.5-72b-instruct", runtime_api_key="or-client-key"
    )
    assert option.provider == "openrouter"
    assert option.api_key == "or-client-key"
    assert option.base_url == "https://openrouter.ai/api/v1"
    assert option.model == "qwen/qwen-2.5-72b-instruct"

    # A plain/unknown id resolves to the default provider with the client key.
    option = client._resolve(None, runtime_api_key="gemini-client-key")
    assert option.provider == "default"
    assert option.api_key == "gemini-client-key"
    assert option.model == s.chat_model


async def test_ask_answers_with_grounded_evidence():
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    candidate = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    indexer = EmbeddingIndexer(_chat_settings(), FakeEmbedder(), FakeStore())
    await indexer.index_job(job)
    await indexer.index_candidate(candidate)

    client = FakeChatClient()
    result = await Ask(_chat_settings(), client, indexer).execute("flutter developer")
    assert result["configured"] is True
    assert result["answer"] == "Jane Doe matches the Flutter role [1]."
    assert result["retrieval"]["enabled"] is True
    assert result["retrieval"]["count"] >= 1
    assert any(source["entity_type"] == "candidate" for source in result["sources"])

    system, user = client.calls[0]
    assert "recruiter copilot" in system.lower()
    assert "[1]" in user
    assert "flutter" in user


async def test_ask_without_rag_notes_missing_evidence():
    client = FakeChatClient()
    result = await Ask(_chat_settings(), client, None).execute("best candidate?")
    assert result["configured"] is True
    assert result["retrieval"]["enabled"] is False
    assert result["retrieval"]["count"] == 0
    system, user = client.calls[0]
    assert "NO WORKSPACE DATA WAS RETRIEVED" in user


async def test_ask_passes_recent_history():
    client = FakeChatClient()
    await Ask(_chat_settings(), client, None).execute(
        "what about cv-2?",
        history=[{"role": "user", "content": "who is best?"}, {"role": "assistant", "content": "cv-1"}],
    )
    system, user = client.calls[0]
    assert "who is best?" in user
    assert "cv-1" in user


async def test_retrieve_evidence_is_diverse_and_bounded():
    job = _job("job-1", "Backend Engineer", description="Python and PostgreSQL services")
    c1 = _candidate("cv-1", "job-1", "Jane Doe", ["Python", "PostgreSQL"])
    c2 = _candidate("cv-2", "job-1", "John Roe", ["Flutter"])
    indexer = EmbeddingIndexer(_chat_settings(), FakeEmbedder(), FakeStore())
    await indexer.index_job(job)
    await indexer.index_candidate(c1)
    await indexer.index_candidate(c2)

    evidence = await retrieve_evidence(indexer, "python", max_evidence=8)
    assert len(evidence) <= 8
    entities = {(item.entity_type, item.entity_id) for item in evidence}
    assert ("candidate", "cv-1") in entities
    # Per-entity cap: cv-1 may appear at most 3 times.
    cv1_count = sum(1 for item in evidence if item.entity_id == "cv-1")
    assert cv1_count <= 3


def test_system_prompt_enforces_scope():
    from app.chat import SYSTEM_PROMPT

    assert "recruiter copilot" in SYSTEM_PROMPT
    assert "decline" in SYSTEM_PROMPT
    assert "[n]" in SYSTEM_PROMPT
    assert "Never invent" in SYSTEM_PROMPT


# --- Copilot tools (function calling) ---


def _registry() -> ToolRegistry:
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    c1 = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    c2 = _candidate("cv-2", "job-1", "John Roe", ["Kotlin"])
    c1.overall_score = 0.9
    c2.overall_score = 0.7
    return ToolRegistry(FakeJobRepo([job]), FakeCvRepo([c1, c2]))


async def test_tool_registry_specs_expose_default_tools():
    registry = _registry()
    names = {spec["function"]["name"] for spec in registry.specs()}
    assert {
        "list_jobs",
        "get_job_detail",
        "list_candidates",
        "get_candidate_detail",
        "get_rankings",
    } <= names


async def test_tool_list_jobs():
    result = await _registry().execute("list_jobs", "{}")
    assert result["jobs"][0]["title"] == "Flutter Developer"
    assert result["jobs"][0]["candidate_count"] == 2
    assert "created_at" in result["jobs"][0]


async def test_tool_get_job_detail():
    result = await _registry().execute("get_job_detail", '{"job_id": "job-1"}')
    assert result["title"] == "Flutter Developer"
    assert result["job_id"] == "job-1"
    assert result["status"] == "open"


async def test_tool_get_job_detail_missing_job():
    result = await _registry().execute("get_job_detail", '{"job_id": "nope"}')
    assert result["error"] == "job_not_found"


async def test_tool_list_candidates_and_detail():
    registry = _registry()
    listing = await registry.execute("list_candidates", '{"job_id": "job-1"}')
    assert listing["candidates"][0]["name"] == "Jane Doe"
    assert listing["candidates"][0]["overall_score"] == 0.9
    detail = await registry.execute(
        "get_candidate_detail", '{"job_id": "job-1", "cv_id": "cv-1"}'
    )
    assert detail["candidate_name"] == "Jane Doe"


async def test_tool_get_rankings_sorts_by_score():
    result = await _registry().execute("get_rankings", '{"job_id": "job-1"}')
    assert result["count"] == 2
    assert result["results"][0]["candidate_name"] == "Jane Doe"
    assert result["results"][0]["rank"] == 1


async def test_tool_unknown_and_invalid_args():
    with pytest.raises(ToolError):
        await _registry().execute("nope", "{}")
    with pytest.raises(ToolError):
        await _registry().execute("get_job_detail", '{"job_id": ""}')
    with pytest.raises(ToolError):
        await _registry().execute("get_job_detail", "not json")


async def test_ask_stream_emits_text_and_done():
    client = FakeStreamingChatClient(["Hel", "lo ", "Flutter"])
    events = [
        event
        async for event in Ask(_chat_settings(), client, None).stream(
            "who is best?", history=[]
        )
    ]
    texts = [e["content"] for e in events if e["type"] == "text"]
    done = [e for e in events if e["type"] == "done"][0]
    assert "".join(texts) == "Hello Flutter"
    assert done["answer"] == "Hello Flutter"
    assert done["configured"] is True


async def test_ask_stream_progress_events_and_gemini_budget():
    """Every route emits started + routing first, then human-friendly status
    events that map to real stages, and preserves the Gemini request budget
    (chitchat=0, deterministic=0, rag_reasoning=1, general=1)."""
    valid_stages = {"routing", "retrieving", "preparing", "reasoning", "answering"}
    registry = _registry()

    async def stages_and_calls(mode, question):
        if mode == "rag_reasoning":
            client = FakeStreamingChatClient(["Jane meets most requirements [1]."])
            ask = Ask(_chat_settings(), client, None, registry)
        elif mode == "general":
            client = FakeStreamingChatClient(["Flutter is a UI toolkit."])
            ask = Ask(_chat_settings(), client, None, None)
        else:
            client = ExplodingChatClient()
            ask = Ask(_chat_settings(), client, None, registry)
        events = [
            event async for event in ask.stream(question, history=[])
        ]
        return events, client

    async def assert_flow(mode, question, expected_stages):
        events, client = await stages_and_calls(mode, question)
        assert events[0]["type"] == "started"
        statuses = [e for e in events if e["type"] == "status"]
        assert statuses and statuses[0]["stage"] == "routing"
        assert [e["stage"] for e in statuses] == expected_stages
        for e in statuses:
            assert e["stage"] in valid_stages
            assert isinstance(e["message"], str) and e["message"]
        assert any(e["type"] == "text" for e in events)
        done = [e for e in events if e["type"] == "done"][0]
        assert done["configured"] is True
        return events, client

    _, client = await assert_flow(
        "chitchat",
        "hi",
        ["routing", "answering"],
    )
    assert isinstance(client, ExplodingChatClient)  # 0 Gemini (would raise)

    _, client = await assert_flow(
        "deterministic",
        "who is the best candidate?",
        ["routing", "retrieving", "preparing"],
    )
    assert isinstance(client, ExplodingChatClient)  # 0 Gemini (would raise)

    _, client = await assert_flow(
        "rag_reasoning",
        "Does this candidate meet the requirements of job-1?",
        ["routing", "retrieving", "preparing", "reasoning"],
    )
    assert len(client.calls) == 1  # rag_reasoning -> exactly 1 Gemini

    _, client = await assert_flow(
        "general",
        "What is Flutter?",
        ["routing", "reasoning"],
    )
    assert len(client.calls) == 1  # general -> exactly 1 Gemini


async def test_ask_ranking_answered_deterministically_no_gemini():
    """'Who is best' resolves through API tools to stored rankings -> ZERO Gemini."""
    registry = _registry()
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)
    result = await ask.execute("who is the best candidate?")
    assert result["configured"] is True
    assert "Jane Doe" in result["answer"]
    assert "0.90" in result["answer"]


async def test_deterministic_sources_carry_status_and_ranked_by():
    """Candidate sources on both the search and ranking paths expose the enriched
    tool fields (status, ranked_by) to the frontend."""
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    c1 = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    c2 = _candidate("cv-2", "job-1", "John Roe", ["Kotlin"])
    c1.overall_score = 0.9
    c1.ranked_by = "admin@ruangguru.com"
    c2.overall_score = 0.7
    registry = ToolRegistry(FakeJobRepo([job]), FakeCvRepo([c1, c2]))
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    search = await ask.execute("who applied for job-1?")
    search_sources = search["sources"]
    assert any(source["entity_type"] == "candidate" for source in search_sources)
    for source in search_sources:
        assert source["status"] == "completed"
        assert "ranked_by" in source

    ranking = await ask.execute("who is the best candidate?")
    ranking_sources = ranking["sources"]
    assert any(source["entity_type"] == "candidate" for source in ranking_sources)
    by_id = {source["entity_id"]: source for source in ranking_sources}
    assert by_id["cv-1"]["ranked_by"] == "admin@ruangguru.com"
    assert all(source["status"] == "completed" for source in ranking_sources)


async def test_deterministic_answers_carry_list_cards():
    """List answers expose structured cards the chat UI renders as tappable
    job/candidate tiles; non-list answers carry an empty cards list."""
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    c1 = _candidate("cv-1", "job-1", "Jane Doe", ["Flutter", "Dart"])
    c1.overall_score = 0.9
    c1.bucket = "strong_match"
    registry = ToolRegistry(FakeJobRepo([job]), FakeCvRepo([c1]))
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    jobs = await ask.execute("which jobs do we have?")
    assert jobs["cards"] == [
        {
            "type": "job",
            "items": [
                {
                    "job_id": "job-1",
                    "title": "Flutter Developer",
                    "status": "open",
                    "candidate_count": 1,
                    "created_at": job.created_at.isoformat(),
                }
            ],
        }
    ]

    candidates = await ask.execute("who applied?")
    assert candidates["cards"] == [
        {
            "type": "candidate",
            "items": [
                {
                    "job_id": "job-1",
                    "cv_id": "cv-1",
                    "name": "Jane Doe",
                    "file_name": "cv-1.txt",
                    "status": "completed",
                    "overall_score": 0.9,
                    "bucket": "strong_match",
                    "ranked_by": None,
                }
            ],
        }
    ]

    ranking = await ask.execute("who is the best candidate?")
    assert ranking["cards"][0]["type"] == "candidate"
    assert ranking["cards"][0]["items"][0]["cv_id"] == "cv-1"

    stats = await ask.execute("how many jobs do we have?")
    assert stats["cards"] == []


async def test_hiring_need_routes_to_candidate_search_with_cards():
    """'i need 2 flutter developer' (a recruiting need) routes to the
    deterministic candidate_search and emits candidate cards, never calling
    Gemini."""
    registry = _registry()
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    result = await ask.execute("i need 2 flutter developer")
    assert result["configured"] is True
    assert "Jane Doe" in result["answer"]
    assert result["cards"] == [
        {
            "type": "candidate",
            "items": [
                {
                    "job_id": "job-1",
                    "cv_id": "cv-1",
                    "name": "Jane Doe",
                    "file_name": "cv-1.txt",
                    "status": "completed",
                    "overall_score": 0.9,
                    "bucket": None,
                    "ranked_by": None,
                }
            ],
        }
    ]

    events = [
        event
        async for event in ask.stream("i need 2 flutter developer", history=[])
    ]
    done = [e for e in events if e["type"] == "done"][0]
    assert done["cards"][0]["type"] == "candidate"
    assert done["cards"][0]["items"][0]["cv_id"] == "cv-1"


async def test_ask_stream_done_emits_cards():
    """The deterministic SSE `done` frame includes the list cards payload."""
    registry = _registry()
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)
    events = [
        event
        async for event in ask.stream("who applied for job-1?", history=[])
    ]
    done = [e for e in events if e["type"] == "done"][0]
    assert done["cards"][0]["type"] == "candidate"
    assert done["cards"][0]["items"][0]["cv_id"] == "cv-1"


async def test_ask_reasoning_prefetches_records_single_gemini_call():
    """Reasoning turns pre-fetch workspace records and make exactly ONE Gemini
    call; Gemini is never offered the tool loop."""
    registry = _registry()
    client = FakeStreamingChatClient(["Jane meets most requirements [1]."])
    ask = Ask(_chat_settings(), client, None, registry)
    events = [
        event
        async for event in ask.stream(
            "Does this candidate meet the requirements of job-1?", history=[]
        )
    ]
    texts = [e["content"] for e in events if e["type"] == "text"]
    tool_events = [e for e in events if e["type"] == "tool"]
    done = [e for e in events if e["type"] == "done"][0]
    assert tool_events == []
    assert "".join(texts) == done["answer"]
    assert len(client.calls) == 1  # exactly one Gemini request
    system, user = client.calls[0]
    assert "recruiter copilot" in system.lower()
    assert "WORKSPACE RECORDS" in user  # data pre-fetched by orchestration
    assert "job-1" in user


async def test_ask_stream_not_configured_errors():
    s = _settings()
    s.llm_api_key = None
    s.openrouter_api_key = None
    events = [event async for event in Ask(s, FakeChatClient(), None).stream("hi")]
    assert events[0]["type"] == "error"
    assert "not configured" in events[0]["message"]


async def test_ask_stream_errors_are_human_friendly():
    """Stream error events must not leak provider/class names (e.g.
    RateLimitError) onto the wire."""
    rate_limited = FailingChatClient("chat_call_failed:RateLimitError")
    events = [
        event
        async for event in Ask(_chat_settings(), rate_limited, None).stream(
            "What is Flutter?"
        )
    ]
    err = [e for e in events if e["type"] == "error"][0]
    assert "RateLimitError" not in err["message"]
    assert "rate limit" in err["message"].lower() or "limit" in err["message"].lower()

    generic = FailingChatClient("chat_call_failed:SomethingBroke")
    events = [
        event
        async for event in Ask(_chat_settings(), generic, None).stream("What is Flutter?")
    ]
    err = [e for e in events if e["type"] == "error"][0]
    assert "SomethingBroke" not in err["message"]
    assert "technical issue" in err["message"].lower()


class _SpecCase:
    def __init__(self, question, intent, mode):
        self.question, self.intent, self.mode = question, intent, mode


def test_router_spec_examples():
    cases = [
        _SpecCase("Do we have any applicant for Flutter?", "candidate_search", "deterministic"),
        _SpecCase("Do we have any Flutter developer?", "job_search", "deterministic"),
        _SpecCase("How many applicants do we have?", "application_statistics", "deterministic"),
        _SpecCase("Who applied for this job?", "candidate_search", "deterministic"),
        _SpecCase("Show me applicants with Flutter experience.", "candidate_search", "deterministic"),
        _SpecCase("Which candidates know Dart?", "candidate_search", "deterministic"),
        _SpecCase("Who has more than 3 years of Flutter experience?", "candidate_search", "deterministic"),
        _SpecCase("Which applicant is the best match for this job?", "candidate_ranking", "deterministic"),
        _SpecCase("Compare the candidates for this position.", "candidate_comparison", "rag_reasoning"),
        _SpecCase("Why is John ranked higher than Sarah?", "candidate_ranking", "deterministic"),
        _SpecCase("Does this candidate meet the job requirements?", "job_requirement_matching", "rag_reasoning"),
        _SpecCase("Find candidates with React and TypeScript experience.", "candidate_search", "deterministic"),
        _SpecCase(
            "find me flutter developer with score more than 70",
            "candidate_search",
            "deterministic",
        ),
        _SpecCase(
            "find flutter developers above 70",
            "candidate_search",
            "deterministic",
        ),
        _SpecCase("i need 2 flutter developer", "candidate_search", "deterministic"),
        _SpecCase("We need 3 backend engineers", "candidate_search", "deterministic"),
        _SpecCase("I am looking for a Flutter developer", "candidate_search", "deterministic"),
        _SpecCase("What experience does this candidate have?", "candidate_detail", "rag_reasoning"),
        _SpecCase("Which candidates match this job description?", "candidate_ranking", "deterministic"),
        _SpecCase("What is Flutter?", "general_question", "general"),
        _SpecCase("What is the difference between Flutter and React Native?", "general_question", "general"),
        _SpecCase("How does Dart work?", "general_question", "general"),
        _SpecCase("What is REST API?", "general_question", "general"),
        _SpecCase("Explain dependency injection.", "general_question", "general"),
        _SpecCase("How should I write a good Flutter job description?", "general_question", "general"),
        _SpecCase("What skills should a junior Flutter developer have?", "general_question", "general"),
    ]
    for case in cases:
        route = QueryRouter.route(case.question)
        assert route.intent == case.intent, (
            f"{case.question!r}: intent {route.intent!r} != {case.intent!r}"
        )
        assert route.mode == case.mode, (
            f"{case.question!r}: mode {route.mode!r} != {case.mode!r}"
        )


async def test_ask_deterministic_queries_skip_gemini():
    """Existential / statistics / skill-filter questions are answered from the
    API tools with ZERO Gemini requests."""
    registry = _registry()
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    result = await ask.execute("Do we have any applicant for Flutter?")
    assert result["configured"] is True
    assert "Jane Doe" in result["answer"]
    assert "Kotlin" not in result["answer"]

    result = await ask.execute("How many applicants do we have?")
    assert "2 applicants" in result["answer"]

    result = await ask.execute("Do we have any Dart developer?")
    assert "job posting" in result["answer"]

    # Streaming path equally stays off-Gemini and emits text + done.
    events = [
        event
        async for event in ask.stream("who applied for job-1?", history=[])
    ]
    assert any(e["type"] == "text" for e in events)
    done = [e for e in events if e["type"] == "done"][0]
    assert "Jane Doe" in done["answer"]


async def test_ask_followup_answers_deterministically_from_tools():
    """A pronoun follow-up after a data turn carries the intent forward and is
    answered from the API tools with ZERO Gemini calls."""
    registry = _registry()
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)
    history = [
        {"role": "user", "content": "Do we have candidate?"},
        {"role": "assistant", "content": "Yes, there are 2 applicants."},
    ]
    result = await ask.execute("What are their skills?", history=history)
    assert result["configured"] is True
    assert "Jane Doe" in result["answer"]
    assert "Flutter" in result["answer"]
    assert "John Roe" in result["answer"]
    assert "Kotlin" in result["answer"]


async def test_ask_score_filter_filters_by_rank():
    """'candidates above 80' filters the deterministic result by ranking score
    (>= 0.80) and never calls Gemini."""
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    names = ["Reyhan", "Fathan", "Rangga", "Rizki"]
    cands = [
        _candidate(f"cv-{i}", "job-1", name, ["Flutter", "Dart"])
        for i, name in enumerate(names, start=1)
    ]
    for cand, score in zip(cands, [0.75, 0.82, 0.90, 0.64]):
        cand.overall_score = score
    registry = ToolRegistry(FakeJobRepo([job]), FakeCvRepo(cands))
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    result = await ask.execute("i need candidate flutter please give candidate above 80")
    assert result["configured"] is True
    assert "Fathan" in result["answer"] and "Rangga" in result["answer"]
    assert "Reyhan" not in result["answer"] and "Rizki" not in result["answer"]

    below = await ask.execute("show flutter candidates above 95")
    assert "There are no candidates matching" in below["answer"]
    assert "create a job and add candidates" in below["answer"]


async def test_ask_score_threshold_more_than_is_strict():
    """'find me flutter developer with score more than 70' must route to
    candidate search (not job search), apply the threshold strictly (> 0.70),
    and never call Gemini. 'above 70' stays inclusive (>= 0.70)."""
    job = _job("job-1", "Flutter Developer", description="Mobile apps")
    names = ["A", "B", "C", "D", "E"]
    cands = [
        _candidate(f"cv-{i}", "job-1", name, ["Flutter", "Dart"])
        for i, name in enumerate(names, start=1)
    ]
    for cand, score in zip(cands, [0.61, 0.70, 0.63, 0.80, 0.71]):
        cand.overall_score = score
    registry = ToolRegistry(FakeJobRepo([job]), FakeCvRepo(cands))
    ask = Ask(_chat_settings(), ExplodingChatClient(), None, registry)

    route = QueryRouter.route("find me flutter developer with score more than 70")
    assert route.intent == "candidate_search"
    assert route.mode == "deterministic"
    assert route.score_filter == (">", 0.70)

    strict = await ask.execute("find me flutter developer with score more than 70")
    assert strict["configured"] is True
    assert "D" in strict["answer"] and "E" in strict["answer"]
    assert "B" not in strict["answer"]

    inclusive = await ask.execute("find flutter developers above 70")
    assert "B" in inclusive["answer"]


async def test_ask_general_question_single_gemini_no_tools():
    """General-knowledge questions go straight to one Gemini call with no tools
    and no retrieval."""
    client = FakeChatClient()
    ask = Ask(_chat_settings(), client, None, None)
    result = await ask.execute("What is Flutter?")
    assert result["configured"] is True
    assert result["answer"] == "Jane Doe matches the Flutter role [1]."
    assert len(client.calls) == 1
    system, user = client.calls[0]
    assert "recruiter copilot" not in system.lower()
    assert "NO WORKSPACE DATA WAS RETRIEVED" not in user


def test_api_chat_disabled(client):
    resp = client.post(
        "/api/chat",
        json={"question": "who is the best flutter candidate?", "history": []},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["configured"] is False
    assert body["sources"] == []


def test_api_chat_stream_disabled(client):
    resp = client.post(
        "/api/chat/stream",
        json={"question": "who is the best flutter candidate?", "history": []},
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")
    assert '"type": "error"' in resp.text
    assert "not configured" in resp.text


def test_api_chat_enabled_by_client_api_key(client):
    """A per-request api_key enables chat even when the server has no key."""
    resp = client.post(
        "/api/chat",
        json={
            "question": "who is the best flutter candidate?",
            "history": [],
            "api_key": "client-key",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["configured"] is True


def test_api_chat_models_lists_configured_providers(client):
    resp = client.get("/api/chat/models")
    assert resp.status_code == 200
    assert resp.json()["models"] == []


def test_resolve_chat_model_falls_back_to_default():
    s = _settings()
    s.llm_api_key = "test-key"
    s.openrouter_api_key = "or-key"
    s.openrouter_models = ["qwen/qwen-2.5-72b-instruct"]

    options = s.chat_models
    assert [o.id for o in options] == [
        "default",
        "openrouter:qwen/qwen-2.5-72b-instruct",
    ]
    default = s.resolve_chat_model(None)
    assert default.id == "default"
    assert default.provider == "default"
    qwen = s.resolve_chat_model("openrouter:qwen/qwen-2.5-72b-instruct")
    assert qwen.provider == "openrouter"
    assert qwen.base_url == "https://openrouter.ai/api/v1"
    assert qwen.model == "qwen/qwen-2.5-72b-instruct"
    assert s.resolve_chat_model("does-not-exist").id == "default"

    s.llm_api_key = None
    s.openrouter_api_key = None
    assert s.resolve_chat_model(None) is None
