# Setup & Testing Guide

How to run the application locally, run its test suites, and smoke-test the API and UI.

## Stack (simple, no external services)

| Layer | Choice |
|-------|--------|
| Backend | Python FastAPI, single process |
| Storage | SQLite (`backend/data/ats.db`) — no database server needed |
| File uploads | Local disk (`backend/data/uploads/`) |
| Ranking | Rule-based scoring always; AI reasoning via any OpenAI-compatible LLM when a key is set |
| Semantic search (RAG) | Opt-in: local bge-small embeddings + Qdrant (embedded/local mode) |

In the default (RAG-disabled) configuration no PostgreSQL, Qdrant, Redis, Docker,
or model downloads are required.

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.9+ (3.12 recommended) | `python3 -m venv` |
| Flutter | 3.x stable | `frontend/` |

---

## 1. Backend — Setup

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### Configure environment (optional)

```bash
cp .env.example .env
```

Nothing needs to be set to run. To enable **AI reasoning** during ranking, set an
OpenAI-compatible endpoint in `.env`. The app defaults to Google Gemini's
OpenAI-compatible endpoint (`gemini-flash-latest`), but any provider works:

```
ATS_LLM__API_KEY=sk-...
ATS_LLM__BASE_URL=https://api.openai.com/v1   # or Gemini/Ollama/vLLM/DeepSeek/...
ATS_LLM__MODEL=gpt-4o-mini                    # or gemini-flash-latest
```

Without a key, the app still ranks candidates and produces template reasoning via
a deterministic rule-based engine.

### Optional: local BERT resume-NER extraction

By default CVs are parsed with deterministic rules (fast), or with an LLM when
`ATS_LLM__API_KEY` is set. To parse CVs with a **local** BERT resume-NER model
instead (runs on CPU in <1s per resume, no API key), install the optional deps
and enable it:

```bash
cd backend
.venv/bin/pip install --index-url https://download.pytorch.org/whl/cpu torch   # ~2GB
.venv/bin/pip install -r requirements-ml.txt
```

```
ATS_EXTRACT__NER=true            # NER takes priority over LLM/rules for CV parsing
ATS_EXTRACT__NER_MODEL=yashpwr/resume-ner-bert
ATS_EXTRACT__NER_CONFIDENCE=0.5
```

Extraction priority is: NER → LLM → rules. The `source` field on each CV records
which engine produced it (`ner` / `llm` / `rules`).

### Optional: semantic search (RAG)

Off by default. When enabled, jobs and CVs are embedded locally with the free
`BAAI/bge-small-en-v1.5` model (the model ~130 MB downloads on first use) and
stored in Qdrant running in **embedded/local mode** (persistent files under
`backend/data/qdrant/` — no server). Set `ATS_QDRANT__URL` to point at a real
Qdrant server instead.

```
ATS_RAG__ENABLED=true
# ATS_RAG__EMBEDDING_MODEL=BAAI/bge-small-en-v1.5   # 384-dim by default
# ATS_RAG__EMBEDDING_VERSION=bge-small-en-v1.5:v1   # bump to force re-embed
# ATS_RAG__TOP_K=20                                 # default search result count
# ATS_QDRANT__PATH=.../data/qdrant                  # embedded mode storage dir
# ATS_QDRANT__URL=http://localhost:6333             # optional real server
# ATS_QDRANT__COLLECTION=recruitment
```

Indexing is automatic: new jobs are embedded on create, CVs are embedded when
background extraction completes, and deletes remove vectors. To index existing
data, run `POST /api/search/reindex` (or pass `{"job_id": "..."}` for a single
job). Semantic search is served by `POST /api/search/semantic` with body
`{"query": "...", "entity": "job"|"candidate", "top_k": 10, "job_id": "..."}`;
when RAG is disabled both endpoints respond with `"enabled": false` and an empty
result set.

### Run the API

```bash
cd backend
.venv/bin/uvicorn app.main:app --reload --port 8000
```

- Interactive docs: <http://localhost:8000/docs>
- Health: <http://localhost:8000/health>

### Recruiter workflow (the whole product)

1. `POST /api/jobs` — describe the job (pasted text and/or an uploaded JD file: PDF/DOCX/TXT). Skills, min years, education, and certifications are extracted automatically.
2. `POST /api/jobs/{id}/candidates/import` — batch-upload CVs (PDF/DOCX/TXT). The request returns immediately with an `import_id`; each CV is parsed **in the background** by a built-in asyncio worker (`POST /api/jobs/{id}/cvs` is a backwards-compatible alias). Track progress with `GET /api/jobs/{id}/imports/{import_id}` or poll `GET /api/jobs/{id}/cvs`.
3. `POST /api/jobs/{id}/rank` — scores and ranks every candidate, best match first, with an explanation, strengths, weaknesses, skill gaps, and a hiring recommendation. A single CV can be ranked with `POST /api/jobs/{id}/cvs/{cv_id}/rank`.
4. `GET /api/jobs/{id}/rankings` — persisted ranking results, best match first.

---

## 2. Frontend — Setup & Run

```bash
cd frontend
flutter pub get
flutter run
```

The app calls `http://127.0.0.1:8000/api` by default. Run the backend first, or
override with:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

Screens: **Jobs** (list) → **New job** (paste description and/or upload a JD file)
→ **Job detail** (add CVs, then "Rank candidates") → **Rankings** (scores +
expandable reasoning).

---

## 3. Testing — Backend

```bash
cd backend
PYTHONPATH=. .venv/bin/python -m pytest tests -q
```

or:

```bash
make backend-test
```

**86 tests, no external services.** `tests/test_api.py` covers: health, create job
from text and from an uploaded JD file, multi-CV upload, ranking order + reasoning,
persisted rankings, and error cases (missing title, missing JD, unknown job).
`tests/test_imports.py` covers the background import pipeline,
`tests/test_jd_skills.py` covers JD structuring + skill matching, and
`tests/test_rag.py` covers chunking, indexing, semantic search, and the
RAG-disabled fallback (all with fake embedders/stores — no model or Qdrant).

### Code check

```bash
make backend-analyze
```

---

## 4. Testing — Frontend

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

---

## 5. API Smoke Test

With the backend running:

```bash
# Health
curl http://localhost:8000/health

# 1. Create a job (paste JD text; upload an optional JD file)
curl -X POST http://localhost:8000/api/jobs \
  -F "title=Senior Backend Engineer" \
  -F "description=Requirements%0A- Python%0A- 5+ years%0AResponsibilities%0A- Build backend services"

# 2. Upload CVs (queued; processed in the background)
curl -X POST http://localhost:8000/api/jobs/<job_id>/candidates/import \
  -F "files=@john.pdf;type=application/pdf" \
  -F "files=@jane.docx"

# 3. Check import progress
curl http://localhost:8000/api/jobs/<job_id>/imports/<import_id>

# 4. Rank all candidates (returns scores + reasoning)
curl -X POST http://localhost:8000/api/jobs/<job_id>/rank

# 5. Persisted rankings (best match first)
curl http://localhost:8000/api/jobs/<job_id>/rankings

# 6. Semantic search over candidates (returns "enabled": false until RAG is on)
curl -X POST http://localhost:8000/api/search/semantic \
  -H "Content-Type: application/json" \
  -d '{"query": "flutter developer", "entity": "candidate", "top_k": 10}'

# 7. Backfill the vector index (after enabling RAG)
curl -X POST http://localhost:8000/api/search/reindex \
  -H "Content-Type: application/json" -d '{}'
```

---

## 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Form data requires python-multipart` | `pip install python-multipart` |
| Port 8000 already in use | Change `--port`, or `lsof -ti:8000 \| xargs kill` |
| Flutter build errors after dep changes | `flutter pub get`, then `flutter clean` |
| Scanned/image-only PDFs yield no text | Not supported yet — convert to text or DOCX |

---

## 7. Quick Reference

```bash
# Backend
cd backend && .venv/bin/uvicorn app.main:app --reload

# Frontend
cd frontend && flutter run

# Tests
make backend-test       # 86 tests
make frontend-test
make lint               # compileall + flutter analyze
```
