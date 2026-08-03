# 14 — Implementation Roadmap

## 1. Delivery Strategy

Build in **vertically-sliced milestones** — each milestone is runnable and demoable end-to-end. Design-first (docs 01–13), then scaffold, then one vertical slice at a time.

## 2. Phases

### Phase 0 — Foundation (Week 1–2)
**Goal**: repo + CI + working skeleton with swappable providers.
- Monorepo layout, docker-compose (pg, qdrant, redis), Alembic baseline migration.
- FastAPI skeleton + `/healthz`, `Settings`, DI container with provider factories.
- Ports/interfaces defined (`EmbeddingProvider`, `LLMProvider`, `VectorStore`, `OCRProvider`, repos).
- Flutter skeleton: theme (M3), router, DI, auth screen.
- CI: lint + unit tests on both repos.
- **Exit criteria**: `docker compose up` runs API+worker; provider selection via env works.

### Phase 1 — Resume Ingestion MVP (Week 3–5)
**Goal**: applicant upload → structured profile → vectors.
- Upload endpoint + object storage + idempotency.
- PDF extraction (digital) + OCR fallback (scanned).
- Section detection/normalization.
- LLM structuring with schema validation + retry.
- Skill taxonomy + canonicalization; `YearsExperienceCalculator`.
- Semantic chunker + BAAI bge-small embedding (local ONNX) + Qdrant upsert.
- Resume status state machine + polling API.
- **Exit criteria**: 10 varied sample PDFs (incl. 2 scanned) all reach `INDEXED`; profile JSON verified in PG; vectors searchable in Qdrant.

### Phase 2 — Search + Heuristic Ranking (Week 6–8)
**Goal**: NL query → ranked candidate buckets (deterministic tier only).
- Query embedding + Qdrant search + profile hydration.
- Intent parsing (rule-based v1).
- Tier-1 scoring (skill/experience/education/certification) + bucket assignment.
- Hidden-gem detector (deterministic signals).
- `POST /search/query` response w/ evidence; result caching; `rankings` persistence.
- Candidate list/detail API + Flutter search/ranking screens.
- **Exit criteria**: recruiter runs 5 canned queries → reasonable buckets; scores reproducible; rankings persisted.

### Phase 3 — LLM Reasoning + Evidence UX (Week 9–11)
**Goal**: explainable rankings.
- Tier-2 LLM reasoner (evidence-constrained prompt, JSON output, chunk-id validation, bounded delta).
- Hybrid BM25 fallback (optional flag).
- Search-by-JD (`POST /search/job`).
- Flutter: evidence drawer, explanation sheet, score gauges, candidate profile + resume viewer.
- **Exit criteria**: explanation text cites only retrieved chunks; UI shows evidence drill-down; eval harness runs.

### Phase 4 — Production Hardening (Week 12–15)
**Goal**: deployable, observable, safe.
- Auth/RBAC (JWT refresh), rate limiting, upload validation + virus scan.
- Observability (OTel traces, Prometheus metrics, structured logs, Sentry).
- Resilience: retries/circuit breakers, DLQ, re-index job, GDPR erasure.
- Terraform modules + CI/CD pipeline; staging env.
- Eval harness (nDCG vs recruiter labels) + golden resume set.
- Flutter: compare screen, jobs CRUD, dashboard.
- **Exit criteria**: staging deploy via pipeline; SLOs monitored; load test 100 resumes + 50 concurrent searches passes.

### Phase 5 — AI Quality + Future Features (Weeks 16+, ongoing)
Staggered per the future-features backlog:
1. **Interview question generator** — reuse chunks per candidate + JD.
2. **Candidate fit score** — persisted, long-lived score per candidate+job.
3. **Bias detection** — score distribution analytics by protected-attribute proxies; equality-of-opportunity-style report.
4. **Salary prediction** — regression over structured profiles + market data (external).
5. **JD optimizer** — LLM suggestions over JD chunks (RAG to best-practice corpus).
6. **AI resume improvement suggestions** — reverse of structuring: profile → suggestions.
7. **Multi-language resumes** — OCR language config + multilingual embeddings (bge-m3 / multilingual-e5).
8. **Analytics dashboard** — funnel, pipeline-quality, retrieval-quality metrics.
9. **Provider upgrades** — swap embeddings to larger model behind version gate; A/B via config.

## 3. Suggested Team & Roles (if full team)

| Role | Focus |
|------|-------|
| 1 Backend ×2 | FastAPI, pipeline, providers |
| 1 AI/ML | RAG, eval harness, embedding tuning |
| 1 Flutter | all client screens |
| 1 DevOps (part-time) | IaC, CI/CD, observability |
| 1 QA/Data | golden dataset, ranking evals |

## 4. Risk Register

| Risk | Mitigation |
|------|-----------|
| LLM structuring errors on messy resumes | schema validation + retries + manual-review queue + golden eval set |
| RAG quality poor on niche queries | hybrid BM25 + eval harness + embedding A/B |
| Provider cost spikes | token budgets, caching, cheaper structuring model, local BGE default |
| Model/provider lock-in | ports + adapters + config-driven selection (doc 05) |
| Compliance (GDPR) | erasure API + audit + data retention policies early |
| Hidden-gem over-suggesting | score thresholds tunable; explainable reasons; recruiter feedback loop |

## 5. Milestone Guardrails

- **Definition of done per slice**: unit + integration tests green, lint clean, CI green, demoable UI, docs updated.
- **No schema changes without Alembic migration** in the same PR.
- **Provider changes** must pass the same golden eval suite before merge (swap-safety guarantee).

## 6. Future Feature Backlog Priority

| Priority | Feature | Depends on |
|----------|---------|-----------|
| P0 | Interview question generator, candidate fit score | Phase 3 |
| P1 | JD optimizer, AI resume suggestions | Phase 3 |
| P2 | Bias detection, analytics dashboard | Phase 4 (data) |
| P3 | Multi-language, salary prediction | Provider + data acquisition |

## 7. Success Metrics (post-launch)

- Pipeline success rate (upload → INDEXED) ≥ 95%.
- Median time-to-index < 30 s; search p95 < 2 s.
- Recruiter time-to-shortlist reduced ≥ 40% vs manual (self-reported).
- Hidden-gem candidates that convert to interview ≥ 15% of shortlist (proves the model adds value beyond years-based filtering).
- Ranking eval nDCG@20 ≥ 0.80 on labeled queries.
