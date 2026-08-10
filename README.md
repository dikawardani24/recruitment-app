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
| Ranking | Deterministic rule-based scoring, plus AI reasoning via any OpenAI-compatible LLM when `ATS_LLM__API_KEY` is set |
| Frontend | Flutter (Material 3) |

## Backend structure

Clean-architecture monorepo (domain → use cases → repositories → datasources →
routers). All HTTP endpoints live under `/api` in `routers/jobs.py`.

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
├── usecase/                # Orchestration: create/list/search/delete job,
│   │                       #   import/list/delete CV, rank (job & CV), rankings
├── di/
│   └── injection.py        # Composition root (manual DI), background worker factory
│
├── domain/                 # Job, Candidate, ImportJob, Page, errors
│
├── routers/
│   └── jobs.py             # All /api endpoints
│
├── parsers/                # File text extraction (PDF, DOCX, TXT)
├── skills/                 # Skill dictionaries + matching
├── jd/                     # JD → structured requirements
├── extraction/             # CV → profile (NER → LLM → rules fallback)
├── imports/                # Background CV processing
│   ├── processor.py        # asyncio worker pool; DB acts as the queue
│   └── pipeline.py         # extract_and_profile orchestration
└── ranking/                # Scoring, buckets, LLM reasoning
```

Each folder is a domain:
- **parsers/** — reads files
- **skills/** — knows what skills are
- **jd/** — parses job descriptions
- **extraction/** — pulls structured data from resumes
- **ranking/** — scores and ranks candidates
- **imports/** — processes uploaded CVs in the background

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

Plus `GET /health` (service health).
