# Setup & Testing Guide

How to run the application locally, run its test suites, and smoke-test the API and UI.

## Stack (simple, no external services)

| Layer | Choice |
|-------|--------|
| Backend | Python FastAPI, single process |
| Storage | SQLite (`backend/data/ats.db`) — no database server needed |
| File uploads | Local disk (`backend/data/uploads/`) |
| Ranking | Rule-based scoring always; AI reasoning via any OpenAI-compatible LLM when a key is set |

No PostgreSQL, Qdrant, Redis, Docker, or model downloads are required.

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
cp ../.env.example .env
```

Nothing needs to be set to run. To enable **AI reasoning** during ranking, set an
OpenAI-compatible endpoint in `.env`:

```
ATS_LLM__API_KEY=sk-...
ATS_LLM__BASE_URL=https://api.openai.com/v1   # or Ollama/vLLM/DeepSeek/...
ATS_LLM__MODEL=gpt-4o-mini
```

Without a key, the app still ranks candidates and produces template reasoning via
a deterministic rule-based engine.

### Run the API

```bash
cd backend
.venv/bin/uvicorn app.main:app --reload --port 8000
```

- Interactive docs: <http://localhost:8000/docs>
- Health: <http://localhost:8000/health>

### Recruiter workflow (the whole product)

1. `POST /api/jobs` — describe the job (pasted text and/or an uploaded JD file: PDF/DOCX/TXT). Skills, min years, education, and certifications are extracted automatically.
2. `POST /api/jobs/{id}/cvs` — batch-upload CVs (PDF/DOCX/TXT). Each is parsed immediately into a structured profile.
3. `POST /api/jobs/{id}/rank` — scores and ranks every candidate, best match first, with an explanation, strengths, weaknesses, skill gaps, and a hiring recommendation.
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

**9 tests, no external services.** `tests/test_api.py` covers: health, create job
from text and from an uploaded JD file, multi-CV upload, ranking order + reasoning,
persisted rankings, and error cases (missing title, missing JD, unknown job).

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

# 2. Upload CVs
curl -X POST http://localhost:8000/api/jobs/<job_id>/cvs \
  -F "files=@john.pdf;type=application/pdf" \
  -F "files=@jane.docx"

# 3. Rank all candidates (returns scores + reasoning)
curl -X POST http://localhost:8000/api/jobs/<job_id>/rank

# 4. Persisted rankings (best match first)
curl http://localhost:8000/api/jobs/<job_id>/rankings
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
make backend-test       # 9 tests
make frontend-test
make lint               # compileall + flutter analyze
```
