# AI-Powered Applicant Ranking

A simple recruiter tool:

1. **Describe a job** — paste the job description and/or upload a JD file (PDF/DOCX/TXT).
2. **Upload CVs** — batch-upload candidates' CV files (PDF/DOCX/TXT).
3. **Rank** — AI scores every candidate, best match first, with per-candidate reasoning: explanation, strengths, weaknesses, skill gaps, and a hiring recommendation.

## Stack

| Layer | Choice |
|-------|--------|
| Backend | Python FastAPI (single process) |
| Storage | SQLite + on-disk file uploads — no external services |
| Ranking | Deterministic rule-based scoring, plus AI reasoning via any OpenAI-compatible LLM when a key is set |
| Extraction | Rule-based by default; local BERT resume-NER or LLM (openai-compatible) when configured |
| Recruiter copilot | Chat Q&A grounded in workspace data (RAG) + API tools; LLM-driven reasoning |
| Semantic search (RAG) | Optional, opt-in: local `bge-small-en-v1.5` embeddings + Qdrant (embedded/local mode) |
| Frontend | Flutter (Material 3) |

## Backend structure

Clean-architecture monorepo (domain → use cases → repositories → datasources →
routers). HTTP endpoints are split across `routers/jobs.py`, `routers/candidates.py`,
`routers/search.py`, and `routers/chat.py`, all mounted under `/api`.

```
backend/app/
├── main.py                 # FastAPI entry point: lifespan, middleware, /health
├── config.py               # Settings dataclass (env-driven, single source of truth)
│
├── database/
│   ├── db_client.py        # SQLite schema + async helpers (aiosqlite)
│   ├── datasource/         # Raw SQL per table: jobs, cvs, import_jobs
│   └── entities/           # Row ↔ dataclass entities
│
├── repository/
│   ├── impl/               # Repository implementations over the datasources
│   └── *.py                # Repository interfaces (job, cv, import_job)
│
├── usecase/                # Orchestration, one file per operation: jobs, CV
│   │                       #   import, ranking, search, chat, unified search
├── di/
│   └── injection.py        # Composition root (manual DI), chat client/tools,
│                           #   lazy RAG indexer, background worker factory
│
├── domain/                 # Job, Candidate, ImportJob, Page, errors
│
├── routers/
│   ├── jobs.py             # /api/jobs/* (create/list/search/detail/delete/rank)
│   ├── candidates.py       # /api/candidates/search
│   ├── search.py           # /api/search (semantic, reindex, unified search)
│   └── chat.py             # /api/chat, /api/chat/stream, /api/chat/models
│
├── parsers/                # File text extraction (PDF, DOCX, TXT)
├── skills/                 # Skill dictionaries + matching
├── jd/                     # JD → structured requirements
├── llm/                    # OpenAI-compatible chat client (gate, throttling, retries)
├── extraction/             # CV → profile (NER → LLM → rules fallback)
├── imports/                # Background CV processing
│   ├── processor.py        # asyncio worker pool; DB acts as the queue
│   └── pipeline.py         # extract_and_profile orchestration
├── chat/                   # Recruiter copilot
│   ├── _router.py          # deterministic query router (no LLM, saves quota)
│   ├── _tools.py           # API tools the copilot answers from (jobs/candidates)
│   ├── _answerer.py        # deterministic + reasoning answer builders
│   ├── _prompt.py          # recruitment-scoped system prompts
│   └── _client.py          # streaming LLM chat client (default + OpenRouter)
├── rag/                    # Semantic search / RAG (opt-in, off by default)
│   ├── _embedder.py        # local bge-small embeddings (lazy-load, free)
│   ├── _chunker.py         # candidate + job semantic chunks
│   ├── _qdrant.py          # Qdrant wrapper (embedded local mode by default)
│   ├── _indexer.py         # idempotent indexing, search, backfill
│   └── _retriever.py       # evidence retrieval for the copilot + semantic search
└── ranking/                # Scoring, buckets, LLM reasoning
```

Each folder is a domain:
- **parsers/** — reads files
- **skills/** — knows what skills are
- **jd/** — parses job descriptions
- **llm/** — talks to LLM providers
- **extraction/** — pulls structured data from resumes
- **ranking/** — scores and ranks candidates
- **imports/** — processes uploaded CVs in the background
- **chat/** — answers recruiter questions (deterministic or LLM-grounded)
- **rag/** — embeds jobs/CVs and answers semantic searches

## Quick start

See [docs/setup-and-testing.md](docs/setup-and-testing.md).

```bash
# Backend
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn app.main:app --reload --port 8000

# Frontend (in another terminal)
cd frontend && flutter pub get && flutter run
```

## Tests

```bash
make backend-test   # pytest
make frontend-test  # flutter test
make lint           # compileall + flutter analyze
```

## Scripts

One-off bash scripts live in `<project>/scripts/*.sh`. They run with their
project directory as the working directory and load the backend `.env` file.

```bash
./scripts/run_script.sh                          # list all scripts
./scripts/run_script.sh run                      # backend run
./scripts/run_script.sh frontend/test            # frontend test
./scripts/run_script.sh frontend/run -d chrome   # pass extra args
```

Or via Make: `make backend-script SCRIPT=seed`.
New scripts are discovered automatically by filename in `<project>/scripts/`.

## API

Base URL: `http://localhost:8000/api`

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/jobs` | Create a job from pasted text and/or a JD file |
| GET | `/api/jobs` | List jobs (paginated) |
| GET | `/api/jobs/search?keyword=` | Search jobs by title/description |
| GET | `/api/jobs/{id}` | Job detail incl. structured requirements |
| DELETE | `/api/jobs/{id}` | Delete a job and everything attached to it |
| POST | `/api/jobs/{id}/candidates/import` | Batch-upload CVs; returns `import_id`, processed in the background |
| POST | `/api/jobs/{id}/cvs` | Backwards-compatible alias for `candidates/import` |
| GET | `/api/jobs/{id}/imports/{import_id}` | Import progress (processed/failed counts) |
| GET | `/api/jobs/{id}/cvs` | List CVs + processing status |
| DELETE | `/api/jobs/{id}/cvs/{cv_id}` | Delete a single candidate |
| POST | `/api/jobs/{id}/rank` | Rank all parsed CVs (LLM reasoning when configured) |
| POST | `/api/jobs/{id}/cvs/{cv_id}/rank` | Rank a single CV |
| GET | `/api/jobs/{id}/rankings` | Persisted rankings, best match first |
| GET | `/api/candidates/search?keyword=` | Search candidates by name/skills/file across all jobs |
| GET | `/api/search?keyword=` | Unified search over jobs and candidates |
| POST | `/api/search/semantic` | Semantic search over jobs or candidates (RAG, opt-in) |
| POST | `/api/search/reindex` | Build/rebuild the vector index (RAG, opt-in) |
| GET | `/api/chat/models` | List available copilot chat models |
| POST | `/api/chat` | Recruiter-copilot Q&A (deterministic or LLM + RAG grounded) |
| POST | `/api/chat/stream` | SSE streaming variant of `/api/chat` |

Plus `GET /health` (service health).

## Semantic search (RAG, opt-in)

Off by default. When enabled, jobs and CVs are embedded locally with the free
`BAAI/bge-small-en-v1.5` model and stored in Qdrant (embedded/local files — no
server needed; set `ATS_QDRANT__URL` to use a real Qdrant server). Indexing
happens automatically as jobs/CVs are created and processed; run
`POST /api/search/reindex` to backfill existing data.

```
ATS_RAG__ENABLED=true
```

See [docs/setup-and-testing.md](docs/setup-and-testing.md) for all RAG settings.

## Recruiter copilot (chat, opt-in)

A chat Q&A ("recruiter copilot") that answers questions about your workspace:
counts, candidate search, rankings, comparisons, and general recruiting advice.
Every question is classified first by a **deterministic router** (no LLM call) so
greetings, chit-chat, and data lookups are answered with zero LLM usage; only
reasoning-heavy questions make a single LLM call, grounded in RAG evidence and
the API tools (jobs, candidates, rankings).

Configured with any OpenAI-compatible endpoint via `ATS_LLM__API_KEY` (defaults to
Gemini), plus optional OpenRouter models (`ATS_OPENROUTER__API_KEY` +
`ATS_OPENROUTER__MODELS`) selectable in the UI. Clients may also save their own
API key in the app (Settings → API Key), which takes precedence per request.

```
ATS_LLM__API_KEY=sk-...
# ATS_OPENROUTER__API_KEY=sk-or-...
# ATS_OPENROUTER__MODELS=qwen/qwen-2.5-72b-instruct
```

Without a key the chat reports `configured: false`; when RAG is disabled it still
answers deterministic questions from the tools alone.
