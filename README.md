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

```
backend/app/
├── main.py              # FastAPI app entry point
├── config.py            # Settings singleton (env vars)
├── db.py                # SQLite schema + async helpers
│
├── parsers/             # File parsing (PDF, DOCX, TXT)
│   ├── __init__.py
│   └── _extract.py
│
├── skills/              # Skill dictionaries + matching
│   ├── __init__.py
│   └── _match.py
│
├── jd/                  # Job description structuring
│   ├── __init__.py
│   └── _structure.py
│
├── extraction/          # CV profile extraction (orchestrator + NER + LLM + rules)
│   ├── __init__.py
│   ├── _profile.py      # Profile dataclass + deterministic extraction
│   ├── _orchestrator.py # NER → LLM → Rules fallback chain
│   └── _ner.py          # Local BERT NER extraction
│
├── ranking/             # Candidate scoring + reasoning
│   ├── __init__.py
│   ├── _scoring.py      # score_profile, bucket_for, rule_reasoning
│   └── _llm.py          # LLM-powered ranking
│
└── routers/
    ├── __init__.py
    └── jobs.py          # All HTTP endpoints
```

Each folder is a domain:
- **parsers/** — reads files
- **skills/** — knows what skills are
- **jd/** — parses job descriptions
- **extraction/** — pulls structured data from resumes
- **ranking/** — scores and ranks candidates

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

One-off bash scripts live in `scripts/<project>/*.sh`. They run with their
project directory as the working directory and load the repo-root `.env` file.

```bash
./scripts/run_script.sh                          # list all scripts
./scripts/run_script.sh run                      # backend run
./scripts/run_script.sh frontend/test            # frontend test
./scripts/run_script.sh frontend/run -d chrome   # pass extra args
```

Or via Make: `make backend-script SCRIPT=seed`.
New scripts are discovered automatically by filename in `scripts/<project>/`.

## API

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/jobs` | Create a job from pasted text and/or a JD file |
| GET | `/api/jobs` | List jobs |
| GET | `/api/jobs/{id}` | Job detail incl. structured requirements |
| POST | `/api/jobs/{id}/cvs` | Upload one or many CV files |
| GET | `/api/jobs/{id}/cvs` | CV processing status |
| POST | `/api/jobs/{id}/rank` | Rank candidates (LLM reasoning when configured) |
| GET | `/api/jobs/{id}/rankings` | Persisted rankings, best match first |
