from __future__ import annotations

import hashlib
import json
import math
from datetime import UTC, datetime

import pytest

from app.config import Settings
from app.chat import ToolCall, ToolError, ToolRegistry
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

    async def complete(self, system: str, user: str, tools=None, execute_tool=None):
        self.calls.append((system, user))
        return "Jane Doe matches the Flutter role [1]."


class FakeStreamingChatClient(FakeChatClient):
    def __init__(self, items):
        super().__init__()
        self.items = items
        self.tool_calls: list[tuple[str, str]] = []

    async def complete_stream(self, system, user, tools=None, execute_tool=None):
        self.calls.append((system, user))
        for item in self.items:
            if isinstance(item, ToolCall):
                await execute_tool(item.name, item.arguments)
                self.tool_calls.append((item.name, item.arguments))
            yield item


def _chat_settings() -> Settings:
    s = _settings()
    s.llm_api_key = "test-key"
    return s


async def test_ask_disabled_when_no_llm_key():
    s = _settings()
    s.llm_api_key = None
    result = await Ask(s, FakeChatClient(), None).execute("who is best?")
    assert result["configured"] is False
    assert "not configured" in result["answer"]


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


async def test_ask_stream_reports_tool_and_executes():
    registry = _registry()
    client = FakeStreamingChatClient(
        [ToolCall("get_job_detail", '{"job_id": "job-1"}'), "Job: Flutter Developer"]
    )
    ask = Ask(_chat_settings(), client, None, registry)
    events = [event async for event in ask.stream("details please", history=[])]
    tool_events = [e for e in events if e["type"] == "tool"]
    assert tool_events == [{"type": "tool", "name": "get_job_detail"}]
    assert client.tool_calls == [("get_job_detail", '{"job_id": "job-1"}')]
    done = [e for e in events if e["type"] == "done"][0]
    assert done["answer"].startswith("Job: Flutter Developer")


async def test_ask_stream_not_configured_errors():
    s = _settings()
    s.llm_api_key = None
    events = [event async for event in Ask(s, FakeChatClient(), None).stream("hi")]
    assert events[0]["type"] == "error"
    assert "not configured" in events[0]["message"]


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
