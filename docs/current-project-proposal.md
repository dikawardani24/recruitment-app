# Project Proposal — AI-Powered CV Pre-Screening Assistant

**Prepared by:** Product & Engineering
**Version:** 1.0
**Date:** August 2026
**Status:** MVP implemented — ready for production hardening

---

## 1. Executive Summary

We propose an AI-powered CV pre-screening assistant that converts job descriptions and
candidate resumes into structured data, scores every candidate against the job, and
returns a ranked shortlist with per-candidate reasoning — strengths, weaknesses,
skill gaps, and a hiring recommendation.

The system is built on a **deterministic, explainable ranking engine**: skills, years of
experience, education, and certifications are matched against the job requirements with
transparent, weighted scores. An optional LLM layer adds narrative reasoning on top of
those scores — it explains, it never decides the rank. This keeps every hiring decision
auditable and reproducible while removing the manual triage burden.

**What we deliver:**

- A working, tested end-to-end application (backend + Flutter UI) — 37/37 backend tests passing.
- Batch CV upload (PDF/DOCX/TXT), automatic profile extraction, and one-click ranking.
- Explainable output for every candidate: score breakdown, bucket, strengths, weaknesses, skill gaps.
- Zero external infrastructure: SQLite + local file storage. AI reasoning is optional and
  provider-agnostic (any OpenAI-compatible endpoint).

**Core promise:** replace manual, error-prone resume triage with a fast, explainable,
evidence-backed shortlist that a recruiter can defend — every rank traces back to
concrete skills and requirements.

---

## 2. The Problem

Recruiting teams lose time and quality to manual screening:

| Pain point | Impact |
|------------|--------|
| **Manual triage cost** | Reading and comparing resumes consumes 30–40% of recruiter time per role, inflating cost-per-hire and time-to-fill. |
| **Inconsistent screening** | Different recruiters weight the same CV differently; decisions are subjective and hard to justify. |
| **No audit trail** | There is no record of *why* a candidate was ranked where they were, making decisions hard to defend or improve. |
| **Skill mismatch blindness** | Candidates with strong but differently-worded experience are easy to overlook when scanning by eye. |

**The opportunity:** a deterministic scoring engine removes the subjectivity. Every
candidate is scored against the same rubric, with the same weights, and the reasoning
behind each score is shown to the recruiter. The result is faster shortlists, higher
consistency, and a defensible audit trail.

---

## 3. The Proposed Solution

An end-to-end pre-screening pipeline with three steps:

```
1. Describe the job    2. Upload CVs       3. Rank & shortlist
Paste JD / upload file   Batch PDF/DOCX/TXT   Ranked candidates, best first,
                         files                 each with score + reasoning
```

### Core capabilities

| Capability | Description |
|------------|-------------|
| **Job structuring** | Paste a job description or upload a JD file; the app normalizes it into structured requirements: required skills, preferred skills, minimum years, education level, certifications. Handles both free text and pre-structured JSON. |
| **Resume parsing** | Batch-upload CVs (PDF/DOCX/TXT). Each is parsed and reduced to a structured profile: candidate name, skills, years of experience, education, certifications. |
| **Deterministic ranking** | Every candidate is scored against the job rubric with transparent, configurable weights. Buckets classify candidates from *strong match* to *weak match*. |
| **Explainable reasoning** | Per-candidate strengths, weaknesses, skill gaps, and a recommendation — generated from the actual scores and matched skills, so every claim is verifiable. |
| **LLM reasoning (optional)** | When an API key is configured, an LLM (any OpenAI-compatible endpoint) enriches ranking with narrative strengths/weaknesses and a recommendation. It is constrained to the extracted data and cannot overturn the deterministic order. |
| **Persisted rankings** | Rankings are stored and re-queryable, best match first, so the audit trail survives the session. |

### Design principles

- **Rules own the rank, AI explains.** The score is computed by transparent formulas
  (`backend/app/ranking/_scoring.py`); the LLM only adds a reasoned narrative.
- **Deterministic fallback.** If no LLM is configured — or it fails — the system still
  returns full rankings from rules alone. AI is an enhancement, never a dependency.
- **Self-contained.** SQLite + local file uploads. No external services required to run.
- **Provider-agnostic.** Any OpenAI-compatible LLM (OpenAI, Gemini, Ollama, etc.) is
  selected by configuration, not code.

---

## 4. Technology Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Backend | Python FastAPI (single process) | Async, typed, ideal for an AI/HTTP pipeline. |
| Storage | SQLite + on-disk uploads | Zero setup, no external services, trivially deployable. |
| Extraction | Local BERT NER → LLM → deterministic rules (fallback chain) | Best-quality extraction when AI is available; guaranteed results without it. |
| Ranking | Deterministic weighted scoring + optional LLM reasoning | Transparent, reproducible, auditable. |
| Frontend | Flutter (Material 3) | One codebase for web/iOS/Android; screens for job management and rankings. |
| LLM | Any OpenAI-compatible endpoint (default: Gemini) | Swappable via env config; `temperature 0` for reproducible output. |

### Key implementation facts

- **Skill matching** (`backend/app/skills/_match.py`): 200+ tech and soft skills plus
  aliases (e.g. `postgres` → `postgresql`, `js` → `javascript`), certifications, and an
  open-vocabulary pass that catches skills not in the dictionary.
- **Ranking weights** (`backend/app/config.py`): skill 0.40, experience 0.30,
  education 0.15, certification 0.15 — all configurable via environment.
- **Buckets**: `strong_match` ≥ 0.85 · `good_match` ≥ 0.70 · `possible_match` ≥ 0.50 · `weak_match`.
- **Status**: 37/37 backend tests passing (`make backend-test`).

---

## 5. System Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    FLUTTER CLIENT (M3)                     │
│  Job list · Job form · Job detail · Rankings              │
└──────────────────────────┬─────────────────────────────────┘
                           │ REST/JSON
┌──────────────────────────▼─────────────────────────────────┐
│                     FASTAPI  (app.main)                    │
│                                                            │
│  routers/jobs.py — create job · upload CVs · rank ·        │
│                     list rankings                          │
│  jd/_structure.py  — normalize JD → requirements           │
│  extraction/       — NER → LLM → rules profile extraction  │
│  skills/_match.py  — skill/cert dictionary + matching      │
│  ranking/          — score_profile · rule_reasoning ·      │
│                      rank_with_llm (optional)              │
└──────┬─────────────────────────────┬───────────────────────┘
       │                             │
       ▼                             ▼
  SQLite (jobs, cvs)          Upload dir (PDF/DOCX/TXT)
  — ground truth, persisted    — raw files kept on disk
    rankings
```

- **Jobs** and **CVs** are stored in SQLite; rankings persist with full score breakdown.
- **Files** are stored on disk under the app's upload directory.
- **Optional external call**: LLM extraction/ranking via any OpenAI-compatible endpoint
  (`ATS_LLM__API_KEY`). Without it, everything still works.

### Data flow

```
Create job → structure JD → requirements (skills, years, education, certs)
Upload CVs → extract text → profile extraction → save to SQLite
Rank job   → score each profile vs requirements → sort → persist
             → (optional) LLM reasoning narrative
View       → GET /jobs/{id}/rankings → ranked list, best first
```

---

## 6. What Is Already Built

| Area | Status |
|------|--------|
| Backend API (`POST/GET /api/jobs`, `/cvs`, `/rank`, `/rankings`) | ✅ Done |
| JD structuring (free text + JSON normalization) | ✅ Done |
| Resume parsing (PDF/DOCX/TXT) + extraction fallback chain | ✅ Done |
| Skill dictionary + open-vocabulary skill detection | ✅ Done |
| Deterministic scoring + buckets + rule reasoning | ✅ Done |
| Optional LLM reasoning tier | ✅ Done |
| Persisted rankings with audit data | ✅ Done |
| Flutter UI (4 screens) | ✅ Done |
| Backend test suite | ✅ 37 passing |
| Interactive script runner (`make backend-script`, `make frontend-test`) | ✅ Done |

### Remaining for production

| Area | Description |
|------|-------------|
| **Authentication & authorization** | JWT login, role-based access (recruiter vs. admin). |
| **Deployment** | Container image (Docker), CI/CD, hosting target. |
| **Observability** | Structured logging, request metrics, error tracking. |
| **Hardening** | Upload validation limits, rate limiting, file virus scanning, data retention/GDPR. |
| **Evaluation dataset** | A golden set of sample resumes + labeled rankings to lock in quality as the app evolves. |

---

## 7. Delivery Roadmap

| Phase | Timeline | Goal | Exit criteria |
|-------|----------|------|---------------|
| **0 · Foundation** | Weeks 1–2 | Repo, CI, API skeleton, DB schema, script runner. | `make backend-test` green; health endpoint up. |
| **1 · Ingestion** | Weeks 3–5 | JD structuring + resume parsing + extraction fallback chain. | 10 sample resumes parse to correct structured profiles. |
| **2 · Ranking** | Weeks 6–8 | Deterministic scoring, buckets, reasoning, persisted rankings. | 5 canned jobs produce sensible, reproducible rankings. |
| **3 · UI** | Weeks 9–10 | Flutter screens: job form, detail, rankings. | End-to-end flow demoable in one session. |
| **4 · Production** | Weeks 11–14 | Auth, observability, deployment, hardening, eval dataset. | Staging deployed; load and eval checks pass. |

> MVP core (Phases 0–3) is already implemented and tested. Phase 4 is the remaining work.

**Suggested team (for Phase 4):** backend engineer (1×), Flutter engineer (1×, part-time),
DevOps (part-time), QA/data (1× part-time).

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Parsing errors on messy resumes** | Three-tier extraction fallback (NER → LLM → rules); extraction failures are reported per-file, never silent. |
| **LLM cost / unavailability** | LLM is optional and fully replaceable via config; deterministic ranking is the default path. |
| **LLM hallucination in reasoning** | LLM is constrained to extracted profile data and cannot change scores; rules own the rank. |
| **Subjective bucket thresholds** | Weights and thresholds are configurable environment variables, tunable per team. |
| **Small-skill-dictionary blind spots** | Open-vocabulary skill pass catches unknown skills; dictionary is a single file to extend. |
| **Inconsistent extraction** | `temperature 0` LLM calls; deterministic rules as the ground truth when AI is absent. |

---

## 9. Success Metrics

| Metric | Target | What it proves |
|--------|--------|----------------|
| **Pipeline reliability** | ≥ 95% uploads reach a parsed/ranked state | Parsing is robust across file formats. |
| **Extraction accuracy** | Verified against a golden sample set | Structured profiles reflect the real resumes. |
| **Ranking consistency** | Reproducible: same job + CVs → same order | The rubric is deterministic and auditable. |
| **Time-to-shortlist** | Reduced ≥ 40% vs manual review | The tool pays for itself in recruiter hours. |
| **Test coverage** | All core ranking/extraction paths covered | Regression-safe as features evolve. |

**Investment summary (indicative):** the MVP is built; Phase 4 is roughly
4–5 team-weeks plus small hosting/infra costs. AI running costs are optional and
minimal at screening volumes.

---

## 10. Next Steps & Call to Action

We have a tested, demoable MVP. To move it into production, we ask for:

1. **Approval** of this proposal and the Phase 4 roadmap.
2. **Pilot dataset** — 20–30 real sample resumes (digital and scanned) to validate parsing quality.
3. **Team allocation** — confirm the Phase 4 roles.
4. **Deployment target** — pick the hosting environment (container host / VM / managed PaaS).

**Immediate milestones after go-ahead:**

| Week | Deliverable |
|------|-------------|
| Week 1 | Docker image + CI pipeline; auth scaffold. |
| Week 2 | Observability + upload hardening; pilot dataset ingested. |
| Week 3 | Staging deployment with the pilot dataset; eval report. |
| Week 4–5 | Go/no-go for production rollout. |

**Contact:** Product & Engineering · placeholder@company.com · Next review: within two weeks of approval.

---

*This proposal supersedes the earlier RAG/vector-search proposal
(`docs/presentation/ATS_Project_Proposal.html`): the delivered system uses a
deterministic scoring + optional-LLM design, which we found sufficient for the
target workload. Vector embeddings remain a possible future enhancement, not part of
this plan.*
