# Setup & Testing Guide

How to run the application locally, run its test suites, and smoke-test the API and UI.

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.11+ | See `backend/.python-version`. Python 3.9 works for tests but Pydantic model annotations require 3.10+ for `str \| None` |
| Docker | any recent | Optional for `docker compose` stack (PostgreSQL, Qdrant, Redis) |
| Flutter | 3.x stable | `frontend/` |
| Tesseract | any | Optional — OCR fallback for scanned PDFs (`brew install tesseract`) |

---

## 1. Backend — Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

> Heavy optional deps (`sentence-transformers`, `paddleocr`, `boto3`, `openai`, `google-genai`) are installed lazily on first use. For a quick dev run without model downloads, use the **debug embedding provider** (see below).

### Configure environment

```bash
cp ../.env.example .env
```

The default `.env` uses the real `bge-small-en-v1.5` embedding model (downloads ~130 MB on first use). To run without any model download, override in `.env`:

```
ATS_EMBEDDING__PROVIDER=debug
```

`debug` produces deterministic hash vectors — fine for exercising the pipeline end-to-end, **not** for meaningful search results.

### Run the API

```bash
uvicorn app.main:app --reload --port 8000
```

- Interactive docs: <http://localhost:8000/docs>
- Health: <http://localhost:8000/healthz> → `{"status": "ok"}`

### Run the worker (resume pipeline)

```bash
arq app.workers.task_queue.WorkerSettings
```

---

## 2. Full Stack — Docker Compose (Recommended)

Brings up API + worker + PostgreSQL + Qdrant + Redis:

```bash
docker compose up --build
```

| Service | URL |
|---------|-----|
| API | http://localhost:8000 |
| Qdrant dashboard | http://localhost:6333/dashboard |
| Postgres | localhost:5432 (`ats`/`ats`) |
| Redis | localhost:6379 |

Compose config sets `ATS_EMBEDDING__PROVIDER=debug` so it runs without model downloads. Stop with `docker compose down` (add `-v` to drop the PG volume).

---

## 3. Frontend — Setup & Run

```bash
cd frontend
flutter pub get
flutter run          # pick a device; web/macOS/iOS/Android are configured
```

The app points at `http://localhost:8000/v1` by default (`Environment.dev` in `lib/app/di.dart`). Run the backend first.

---

## 4. Testing — Backend

```bash
cd backend
PYTHONPATH=. .venv/bin/python -m pytest tests/ -q
```

or via Makefile:

```bash
make backend-test
```

**8 tests, no external services required.** The suites are:

- `tests/unit/test_domain_services.py` — skill canonicalization, years-of-experience calc, fast-progression heuristic.
- `tests/unit/test_ranking_engine.py` — bucket assignment (best / strong / hidden gem / alternative) and hidden-gem signals.
- `tests/integration/test_pipeline_search.py` — full search → rank flow using an in-memory `VectorStore` fake (Qdrant not needed).

### Code check

```bash
make backend-analyze      # compileall smoke check
```

### What needs real services (later milestones)

The resume upload → OCR → structuring → Qdrant indexing path is not yet wired to a live worker/vector store. Until Phase 1 lands, pipeline tests use fakes; real integrations are covered by `docs/14-implementation-roadmap.md`.

---

## 5. Testing — Frontend

```bash
cd frontend
flutter analyze
flutter test
```

or via Makefile:

```bash
make frontend-test
make frontend-analyze
```

**4 tests, analyzer clean.** Coverage: theme seeding, `RankedCandidate` API parsing, and `SearchCubit` state transitions.

---

## 6. API Smoke Test

With the backend running (or `docker compose up`):

```bash
# Health
curl http://localhost:8000/healthz

# Natural-language search (needs Qdrant running + indexed data; see note below)
curl -X POST http://localhost:8000/v1/search/query \
  -H "Content-Type: application/json" \
  -d '{"query": "Find Senior Flutter Developers with banking experience", "top_k": 20}'

# Resume upload (needs object storage + worker pipeline configured)
curl -X POST http://localhost:8000/v1/resumes/upload \
  -F "file=@resume.pdf"

# Poll processing status
curl http://localhost:8000/v1/resumes/<resume_id>
```

> **Note:** `POST /search/query` currently requires a running vector store (Qdrant) and returns an empty result set until candidates are indexed. The deterministic ranking logic is fully exercised by the backend test suite without infrastructure.

---

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Settings has no attribute top_k` | Stale code — re-pull/pull latest; bug fixed in DI container wiring |
| `Form data requires python-multipart` | `pip install python-multipart` |
| `sentence-transformers not installed` | Use `ATS_EMBEDDING__PROVIDER=debug` or `pip install sentence-transformers` |
| `qdrant-client not installed` | `pip install qdrant-client` or run the stack via Docker |
| `pydantic ... 'str \| None'` | Use Python 3.10+ (see `.python-version`) |
| Flutter `getIt`/Dio errors on first run | `flutter pub get`, then `flutter clean` if stale |
| Port 8000 already in use | Change `--port`, or `lsof -ti:8000 | xargs kill` |

---

## 8. Quick Reference

```bash
# Full stack
docker compose up --build

# Backend only (debug embeddings)
cd backend && source .venv/bin/activate
uvicorn app.main:app --reload --port 8000

# Tests
make backend-test       # 8 tests
make frontend-test      # 4 tests
make lint               # compileall + flutter analyze
```
