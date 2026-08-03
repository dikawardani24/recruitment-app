# 04 — Folder Structure

## 1. Monorepo Layout

```
ai-ats/
├── README.md
├── Makefile
├── docker-compose.yml            # local: api + worker + pg + qdrant + redis
├── .env.example
├── docs/                         # design deliverables 01–14
│   ├── 01-system-architecture.md
│   ├── ...
│   └── 14-implementation-roadmap.md
│
├── backend/                      # Python FastAPI monorepo
│   ├── pyproject.toml / requirements.txt
│   ├── alembic/                  # migrations
│   │   ├── env.py
│   │   └── versions/
│   ├── app/
│   │   ├── main.py               # FastAPI app factory
│   │   ├── core/                 # config, DI container, ports
│   │   ├── domain/               # entities, value objects, enums
│   │   ├── application/          # use cases (orchestration, business rules)
│   │   ├── infrastructure/       # adapters (pg, qdrant, providers, workers)
│   │   └── api/                  # routers, schemas, deps
│   ├── workers/                  # background worker entrypoints
│   └── tests/
│
└── frontend/                     # Flutter app
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── app/                  # app config, DI, router, theme
    │   ├── core/                 # network, storage, constants, widgets, errors
    │   ├── features/
    │   └── shared/               # models shared across features
    └── test/
```

## 2. Backend — Detailed

```
backend/app/
├── core/
│   ├── config.py                 # pydantic-settings: env, providers, models
│   ├── container.py              # DI container (see doc 05)
│   ├── ports/
│   │   ├── embedding_provider.py
│   │   ├── llm_provider.py
│   │   ├── vector_store.py
│   │   ├── ocr_provider.py
│   │   ├── object_storage.py
│   │   ├── file_parser.py
│   │   └── repositories.py       # CandidateRepo, ResumeRepo, ...
│   ├── enums.py                  # ResumeStatus, Section, Bucket, Role
│   ├── exceptions.py
│   └── events.py                 # domain events + event bus
│
├── domain/
│   ├── entities/
│   │   ├── candidate.py          # Candidate, Experience, Education, ...
│   │   ├── resume.py
│   │   ├── job.py
│   │   └── ranking.py
│   ├── value_objects.py          # Email, Skill, DateRange, Score
│   └── services/
│       ├── skill_normalizer.py
│       └── years_experience.py
│
├── application/
│   ├── use_cases/
│   │   ├── resumes/
│   │   │   ├── upload_resume.py
│   │   │   ├── process_resume.py        # pipeline orchestrator (state machine)
│   │   │   ├── get_resume_status.py
│   │   │   └── reindex_resume.py
│   │   ├── candidates/
│   │   │   ├── get_candidate.py
│   │   │   ├── list_candidates.py
│   │   │   └── delete_candidate.py      # GDPR erasure
│   │   ├── search/
│   │   │   ├── search_candidates.py
│   │   │   └── match_job.py
│   │   ├── ranking/
│   │   │   ├── rank_candidates.py       # orchestrates hybrid ranking
│   │   │   ├── hidden_gem.py
│   │   │   └── llm_reasoner.py
│   │   ├── jobs/
│   │   │   ├── create_job.py
│   │   │   └── update_job.py
│   │   └── applications/
│   │       ├── create_application.py
│   │       └── update_application.py
│   ├── dto/                     # data transfer objects
│   └── interfaces/              # abstract use-case in/out ports (if needed)
│
├── infrastructure/
│   ├── persistence/
│   │   ├── postgres/
│   │   │   ├── db.py            # async engine, session
│   │   │   ├── models.py        # SQLAlchemy ORM
│   │   │   └── repositories/    # CandidateRepository, ResumeRepository, ...
│   │   └── cache.py             # redis (result cache, rate limit)
│   ├── vector/
│   │   ├── qdrant_store.py      # QdrantVectorStore (port impl)
│   │   └── migrations/          # collection creation / versioning
│   ├── providers/
│   │   ├── embeddings/
│   │   │   ├── base.py
│   │   │   ├── openai_embedding.py
│   │   │   ├── gemini_embedding.py
│   │   │   └── local_bge.py     # sentence-transformers / ONNX
│   │   ├── llm/
│   │   │   ├── base.py
│   │   │   ├── openai_llm.py
│   │   │   ├── gemini_llm.py
│   │   │   ├── ollama_llm.py    # llama, qwen, deepseek
│   │   │   └── vllm_llm.py      # any OpenAI-compatible endpoint
│   │   ├── ocr/
│   │   │   ├── base.py
│   │   │   ├── tesseract_ocr.py
│   │   │   └── paddle_ocr.py
│   │   ├── parsers/
│   │   │   ├── pdf_digital.py   # pypdf / pdfplumber
│   │   │   └── pdf_scanned.py   # rasterize + OCR
│   │   └── storage/
│   │       ├── s3_storage.py
│   │       └── local_storage.py
│   ├── ai/
│   │   ├── structuring.py       # resume → JSON via LLM (doc 08)
│   │   ├── chunker.py           # semantic chunking (doc 10)
│   │   ├── embedding_service.py
│   │   └── validation.py        # JSON-schema validation, retries
│   ├── workers/
│   │   ├── task_queue.py        # ARQ/Celery wrappers, retries, DLQ
│   │   └── tasks/
│   │       ├── process_resume_task.py
│   │       ├── reindex_task.py
│   │       └── notify_task.py
│   └── observability/
│       ├── logging.py
│       ├── tracing.py           # OpenTelemetry
│       └── metrics.py           # Prometheus
│
├── api/
│   ├── deps.py                  # FastAPI dependencies (auth, container)
│   ├── routers/
│   │   ├── auth.py
│   │   ├── resumes.py
│   │   ├── candidates.py
│   │   ├── search.py
│   │   ├── jobs.py
│   │   ├── applications.py
│   │   ├── dashboard.py
│   │   └── admin.py
│   ├── schemas/                 # Pydantic request/response models
│   │   ├── candidate.py
│   │   ├── search.py
│   │   ├── ranking.py
│   │   └── ...
│   └── middlewares.py           # auth, correlation-id, rate-limit, CORS
│
└── tests/
    ├── unit/
    │   ├── domain/              # pure logic: years calc, skill normalization
    │   ├── application/         # use cases with fakes
    │   └── infrastructure/      # adapter unit tests
    ├── integration/
    │   ├── test_pipeline.py     # real pg + qdrant (testcontainers)
    │   └── test_search.py
    └── e2e/
        └── test_api.py
```

## 3. Frontend (Flutter) — Detailed

```
frontend/lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp.router, themes
│   ├── di.dart                  # service locator (get_it) wiring
│   ├── router.dart              # go_router routes + guards
│   ├── theme/
│   │   ├── app_theme.dart       # Material 3 ColorScheme
│   │   └── text_styles.dart
│   └── environment.dart
│
├── core/
│   ├── network/
│   │   ├── api_client.dart      # dio + interceptors (auth, retry)
│   │   ├── api_exception.dart
│   │   └── endpoints.dart
│   ├── storage/
│   │   ├── secure_storage.dart  # tokens
│   │   └── local_cache.dart
│   ├── utils/
│   ├── errors/                  # error mapper → user messages
│   └── widgets/
│       ├── score_gauge.dart
│       ├── bucket_badge.dart
│       ├── chunk_evidence_card.dart
│       ├── file_uploader.dart
│       └── ...
│
├── features/
│   ├── auth/
│   │   ├── data/                # datasource + repository impl
│   │   ├── domain/              # entities + repository interface
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       └── auth_cubit.dart / auth_bloc.dart
│   ├── resume_upload/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # upload_screen, progress_poller, status_view
│   ├── candidate_profile/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # profile_screen, sections, resume_viewer
│   ├── search/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # search_screen, query_bar, results_list
│   ├── ranking/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # ranking_screen, buckets, score_cards,
│   │                            #   explanation_sheet, evidence_drawer
│   ├── compare/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # compare_screen, comparison_table,
│   │                            #   ai_summary_panel
│   ├── jobs/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/        # job_list, job_form, job_detail, rank_button
│   └── dashboard/
│       ├── data/
│       ├── domain/
│       └── presentation/        # dashboard_screen, metrics_cards
│
└── shared/
    ├── models/                  # Candidate, Resume, RankingResult, Chunk
    └── widgets/                 # shared ui components
```

## 4. Infrastructure as Code

```
infra/
├── terraform/
│   ├── modules/
│   │   ├── api/                 # ECS/Fargate service
│   │   ├── worker/              # ECS/Fargate worker
│   │   ├── db/                  # RDS PostgreSQL
│   │   ├── qdrant/              # ECS qdrant service
│   │   ├── cache/               # Elasticache Redis
│   │   └── cdn/                 # CloudFront for resume viewer
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── k8s/                         # (alternative to ECS)
│   ├── base/  ├── overlays/
├── docker/
│   ├── api.Dockerfile
│   ├── worker.Dockerfile
│   └── qdrant.Dockerfile
└── .github/workflows/
    ├── backend-ci.yml
    ├── frontend-ci.yml
    └── deploy.yml
```

## 5. Directory Rules

- **Backend**: `domain` + `application` never import `infrastructure` or `api` (inversion of dependency, doc 05). Adapters implement `core/ports` interfaces.
- **Frontend**: `presentation` never imports `data` directly; features depend on `domain` interfaces; `core` is shared infrastructure only.
- **Config** lives only in `core/config.py` / `app/environment.dart` — no hard-coded URLs or model names in business code.
