# 04 — Folder Structure

> This document reflects the **current implemented** layout. Docs 01–13 describe
> the target design; the code is a simplified, single-process subset of it.

## 1. Monorepo Layout

```
recruitment-app/
├── README.md
├── Makefile                  # backend/frontend run, test, analyze shortcuts
├── scripts/                  # one-off bash scripts (run_script.sh runner)
├── docs/                     # design deliverables 01–14 + backend-flow + setup
├── backend/                  # Python FastAPI (single process)
└── frontend/                 # Flutter app (Material 3)
```

## 2. Backend — Detailed

```
backend/
├── pyproject.toml / requirements.txt
├── data/                     # runtime: ats.db (SQLite) + uploads/ (CV/JD files)
├── app/
│   ├── main.py               # FastAPI entry point: lifespan, middleware, /health
│   ├── config.py             # Settings dataclass (env-driven)
│   ├── database/
│   │   ├── db_client.py      # SQLite schema (jobs, cvs, import_jobs) + async helpers
│   │   ├── datasource/       # Raw SQL per table: job, cv, import_job
│   │   └── entities/         # Row ↔ dataclass entities
│   ├── repository/
│   │   ├── job_repository.py / cv_repository.py / import_job_repository.py
│   │   └── impl/             # Implementations over the datasources
│   ├── usecase/              # Orchestration (one file per operation)
│   │   ├── save_job, get_job, get_job_by_page, search_jobs, delete_job
│   │   ├── import_cv_batch, list_cvs, delete_cv
│   │   ├── rank_job, rank_cv, get_rankings
│   │   ├── get_import_status
│   │   └── semantic_search, reindex_embeddings   # RAG (opt-in)
│   ├── di/
│   │   ├── injection.py      # Composition root (manual DI), cv_processor()
│   │   └── __init__.py
│   ├── domain/               # Job, Candidate, ImportJob, Page, errors
│   ├── routers/
│   │   ├── jobs.py           # All /api/jobs/* endpoints
│   │   └── search.py         # /api/search/semantic + /api/search/reindex
│   ├── parsers/              # File text extraction (_extract.py: PDF/DOCX/TXT)
│   ├── skills/               # Skill dictionaries + matching (_match.py)
│   ├── jd/                   # JD → structured requirements (_parser.py, _structure.py)
│   ├── extraction/           # CV → profile (NER → LLM → rules)
│   │   ├── _profile.py       # Profile dataclass + deterministic extraction
│   │   ├── _orchestrator.py  # NER → LLM → Rules fallback chain
│   │   └── _ner.py           # Local BERT NER extraction
│   ├── imports/              # Background CV processing
│   │   ├── processor.py      # asyncio worker pool; DB-as-queue
│   │   └── pipeline.py       # extract_and_profile orchestration
│   ├── rag/                  # Semantic search / RAG (opt-in, off by default)
│   │   ├── _embedder.py      # local bge-small embeddings (lazy-load)
│   │   ├── _chunker.py       # candidate + job semantic chunks
│   │   ├── _qdrant.py        # Qdrant wrapper (embedded/local mode by default)
│   │   └── _indexer.py       # idempotent indexing, search, backfill
│   ├── ranking/              # Scoring, buckets, LLM reasoning
│   │   ├── _scoring.py       # score_profile, bucket_for, rule_reasoning
│   │   ├── _llm.py           # LLM-powered reasoning
│   │   ├── _requirements.py, _profile_score_counter.py, _service.py
│   └── util/                 # file_util, str_util, date_util
└── tests/
    ├── conftest.py
    ├── test_api.py           # endpoint smoke tests
    ├── test_imports.py       # background import flow
    ├── test_jd_skills.py     # JD structuring + skill matching
    ├── test_llm_extract.py   # LLM extraction (mocked)
    ├── test_ner_extract.py   # NER extraction (mocked)
    └── test_rag.py           # chunking, indexing, semantic search (fake embedder)
```

## 3. Frontend (Flutter) — Detailed

Clean-architecture layout: `domain → data → controllers → screens`, with
`navigation`, `widgets`, and `theme` shared across screens.

```
frontend/lib/
├── main.dart                 # app bootstrap: DI init, provider overrides, GoRouter
├── router.dart               # go_router route table (routes derived from AppRoute)
├── providers.dart            # Riverpod providers (jobs, cvs, rankings, navigation)
├── di.dart / di.config.dart  # get_it + injectable wiring (generated)
│
├── domain/
│   ├── models/               # Job, CandidateResult, JobPage, JobRequirements,
│   │                         #   RankResponse, ImportResult
│   ├── repositories/         # JobRepository, CandidateRepository interfaces
│   └── usecases/             # create/delete/list/search job, list/delete/rank CV,
│                             #   get job, get rankings, get import status
│
├── data/
│   ├── api/                  # ApiClient (dio), ApiPaths, mappers, response models
│   ├── data_sources/         # JobApiDataSource, CandidateApiDataSource
│   └── repositories/         # JobRepositoryImpl, CandidateRepositoryImpl
│
├── controllers/              # Riverpod controllers/notifiers per screen
│   ├── job_list_controller.dart
│   ├── jobDetail/            # job_detail_controller, _notifier, _state
│   ├── jobForm/              # job_form_controller, _state, picked_jd_file
│   ├── rankings_controller.dart
│   ├── upload/               # upload_controller, _state
│   └── deleteConfirm/        # delete_confirm_controller, _state
│
├── navigation/
│   ├── app_route.dart        # AppRoute enum (single source of path truth)
│   ├── app_navigator.dart    # AppNavigator interface + shared data types
│   └── go_router_navigator.dart  # go_router-backed AppNavigator
│
├── screens/                  # One file per screen
│   ├── job_list_screen.dart
│   ├── search_job_screen.dart
│   ├── job_form_screen.dart
│   ├── job_detail_screen.dart
│   ├── candidate_detail_screen.dart
│   ├── rankings_screen.dart
│   ├── delete_confirm_screen.dart
│   ├── action_result_screen.dart
│   └── settings_screen.dart
│
├── widgets/                  # Shared UI components
│   ├── deferred_page.dart    # smooth page transitions (defer heavy builds)
│   ├── bucket_donut.dart, score_color.dart, rank_engine_chip.dart
│   ├── job_card.dart, job_list_footer.dart, gradient_header.dart
│   ├── section_card.dart, card_shape.dart, accent_chip.dart
│   ├── cv_upload_overlay.dart, loading_overlay.dart, shimmer.dart
│   ├── delete_background.dart, error_view.dart, rankings_summary.dart
│   └── ...
│
└── theme/
    ├── app_theme.dart        # Material 3 ColorScheme
    └── theme_controller.dart # light/dark/system theme mode (Riverpod)
```

## 4. Directory Rules

- **Backend**: `domain` and `usecase` never import `database`, `repository`, or
  `routers` implementations — use cases depend on repository interfaces; the
  composition root (`di/injection.py`) wires concrete implementations.
- **Frontend**: `screens` and `controllers` depend on `domain` interfaces and
  `data` repository impls (via get_it); `data` contains all third-party/API
  concerns; `navigation` is the only place go_router is touched.
- **Config** lives only in `backend/app/config.py`; the Flutter base URL is
  injected via `--dart-define=API_BASE_URL`.
