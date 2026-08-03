# 07 — Backend Architecture

## 1. Overview

FastAPI (async) application composed of:

- **API process** — serves HTTP, lightweight, stateless, horizontally scalable.
- **Worker process** — consumes jobs from Redis queue (ARQ or Celery) for the resume pipeline and re-indexing.
- Shared codebase (`app/`) using Clean Architecture (doc 05); both processes run the same container graph.

```
        ┌───────────────┐        ┌────────────────────┐        ┌───────────────┐
        │  API process  │        │  Redis (queue/cache)│        │  Worker process│
        │  uvicorn      │───────▶│                    │───────▶│  pipeline      │
        │  sync search  │        │  ARQ/Celery broker │        │  parse→struct  │
        │               │        └────────────────────┘        │  chunk→embed   │
        └───────────────┘                                       └───────────────┘
              │                                                         │
              │ PG + Qdrant + Object Storage + Providers (shared)        │
```

## 2. Request Lifecycle

```
HTTP request
  → CORS / rate-limit / correlation-id middlewares
  → auth dependency (JWT → RBAC)
  → router resolves container use case via deps.py
  → use case (application layer) orchestrates domain + ports
  → response serialized by Pydantic schema
```

## 3. Async Strategy

| Work | Sync (in API request) | Async (worker) |
|------|------------------------|-----------------|
| Candidate search + ranking | ✅ (needs immediate response; LLM reasoning kept lean with timeout) | — |
| Resume upload acceptance | ✅ (store file, enqueue) | — |
| PDF text extraction | — | ✅ |
| OCR fallback | — | ✅ |
| LLM structuring | — | ✅ |
| Chunking + embedding | — | ✅ |
| Qdrant upsert | — | ✅ |
| Re-index / model upgrade | — | ✅ |

- Long search→rank flows that invoke LLM run with **streaming/partial fallback**: if LLM reasoning exceeds `search.llm_timeout_ms`, return heuristic ranking immediately with `meta.reasoning="heuristic"`.
- Task queue: **ARQ** (lightweight, asyncio-native). Celery optional for teams preferring it. Idempotent task IDs keyed by `resume_id` prevent double-processing.

## 4. Database Layer

- **SQLAlchemy 2.0 async** (`asyncpg` driver), Alembic migrations.
- **Repositories** (doc 05) implement application ports; transactions opened/committed inside use cases.
- **JSONB** for the structured profile — flexible schema evolution without migrations on every model change.
- **Redis** for: task queue, search-result cache (keyed by query signature), rate limiting, pipeline-status pub/sub.

## 5. Vector Layer

- `QdrantVectorStore` adapter implements `VectorStore` port.
- Collections versioned by `embedding_model + embedding_version` so mixed indexes never serve stale vectors.
- Search executed with payload filters (skill, section, candidate_id) before/after vector similarity.

## 6. AI Provider Layer

- Factory pattern: `EmbeddingFactory`, `LLMFactory`, `OCRFactory` read config and instantiate adapters (doc 05 §3).
- **LLMProvider interface** supports:
  - `complete(system, user, json_mode, temperature)` — used by structuring + ranking.
- **EmbeddingProvider interface** supports `embed(texts)`. BAAI bge-small-en-v1.5 runs via `sentence-transformers` or ONNX for CPU efficiency (384-dim).
- Circuit breakers + timeout per provider; batch embeddings; concurrency limits to avoid provider rate limits.

## 7. Structuring Pipeline (Application layer use case)

```
ProcessResumeUseCase.execute(resume_id):
 1  load resume row, lock (row lock to prevent double processing)
 2  if status in terminal states → no-op
 3  update status=PARSING
 4  try text = parser.extract()                # digital
 5  except LowTextDensity → status=OCR → text = ocr.extract(pages)
 6  text = cleaner.clean(text)
 7  status=STRUCTURING
 8  profile_json = llm_structuring.structure(text)   # JSON schema enforced
 9  profile = validate_and_normalize(profile_json)    # skills taxonomy, dates, ids
10  status=CHUNKING
11  chunks = chunker.chunk(profile, resume_id)
12  vectors = embedding.embed([c.text for c in chunks])
13  status=INDEXING
14  vector_store.upsert(chunks, model, version)       # idempotent by chunk_id
15  persist profile + derived metrics → status=INDEXED
16  emit ResumeIndexedEvent
  (any failure → status=FAILED, error_detail populated, retry ≤ 3)
```

## 8. Search Pipeline (use case)

```
SearchCandidatesUseCase.execute(query, filters, top_k):
 1  qvec = embedding.embed([query])[0]
 2  hits = vector_store.search(qvec, filters, top_k)
 3  candidate_ids = dedupe(hits)                    # group by candidate_id
 4  profiles = candidate_repo.get_many(candidate_ids)   # hydrate from PG
 5  ranking = ranking_engine.rank(profiles, hits, query)
      → heuristic composite scores (deterministic, fast)
      → optional LLM reasoning on evidence (bounded timeout)
 6  persist rankings (audit) + cache result
 7  return bucket-sorted ranked candidates + evidence
```

## 9. Observability

- **Tracing**: OpenTelemetry spans per request + per pipeline stage (upload, parse, structure, embed, rank).
- **Metrics (Prometheus)**: pipeline stage latency/duration, LLM token usage, vector search latency, queue depth, failure rates by provider.
- **Logs**: structured JSON with `correlation_id` + `resume_id`/`candidate_id` context; sensitive data redacted.
- **Sentry**: error tracking with `resume_id` context for pipeline failures.

## 10. Resilience & Failure Handling

| Scenario | Handling |
|----------|----------|
| Provider timeout/5xx | Retry (3×, exp backoff) then circuit-break open 30s |
| Embedding dim mismatch (model change) | Version-gated collections; migration job re-embeds |
| Qdrant down | Search fails fast with cached results; pipeline holds; alerts |
| PG down | Healthcheck; API 503; queue drains; resume survives in object storage |
| Worker crash mid-stage | Idempotent stage tasks; resume row lock + status checkpoint resumes from failed stage |
| Duplicate upload | Idempotency key (file hash) → returns existing resume_id |

## 11. Security

- JWT access (15 min) + refresh (7 day rotation), argon2 password hashing.
- RBAC roles: applicant / recruiter / admin enforced at router dependency level.
- Upload: size/type validation, magic-byte check, antivirus (ClamAV) scan in worker.
- Secrets: env / SSM / Vault; never in code. CSP + CORS allowlist. TLS everywhere.
- Data minimization: PII access logged in `audit_logs`; erasure deletes PG + Qdrant points.

## 12. Configuration Surface (`Settings`)

```yaml
db: { url, pool_size, max_overflow }
redis: { url }
vector: { provider: "qdrant", url, collection_prefix, distance: "cosine" }
storage: { provider: "s3" | "local", bucket, region }
providers:
  embedding: { provider: "bge-small-en-v1.5" | "openai" | "gemini", dim: 384, batch_size: 32, model: "BAAI/bge-small-en-v1.5" }
  llm: { provider: "openai" | "gemini" | "ollama" | "vllm", model, base_url, temperature, json_mode }
  ocr: { provider: "tesseract" | "paddle", lang }
search: { top_k, candidate_count, llm_timeout_ms, min_score }
pipeline: { retries, dlq, concurrency }
```
