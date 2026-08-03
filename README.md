# AI-Powered Applicant Tracking System (ATS)

A production-ready, AI-native ATS that transforms resumes into **structured candidate profiles**, indexes them with **semantic embeddings**, and ranks candidates using **retrieval-augmented generation (RAG) + LLM reasoning** — replacing keyword matching with semantic search and explainable AI ranking.

## Core Promise

- **Not a "chat with your PDF" tool.** Every resume is parsed, normalized, and transformed into structured JSON before indexing.
- **Semantic matching** over candidate skills, experience, projects, and certifications — not keyword grep.
- **Explainable ranking**: each candidate gets scores, strengths, weaknesses, and a reason.
- **Hidden-gem detection**: high-potential candidates with fewer years of experience are not rejected.

## Repositories Layout

```
ai-ats/
├── docs/          # Full design package (14 deliverables)
├── backend/       # Python FastAPI — Clean Architecture
└── frontend/      # Flutter (Material 3) — Clean Architecture
```

## Documentation Index

| # | Deliverable | File |
|---|-------------|------|
| 1 | Complete System Architecture | [docs/01-system-architecture.md](docs/01-system-architecture.md) |
| 2 | Database ERD | [docs/02-database-erd.md](docs/02-database-erd.md) |
| 3 | API Specification | [docs/03-api-specification.md](docs/03-api-specification.md) |
| 4 | Folder Structure | [docs/04-folder-structure.md](docs/04-folder-structure.md) |
| 5 | Clean Architecture Layers | [docs/05-clean-architecture-layers.md](docs/05-clean-architecture-layers.md) |
| 6 | Flutter Application Architecture | [docs/06-flutter-architecture.md](docs/06-flutter-architecture.md) |
| 7 | Backend Architecture | [docs/07-backend-architecture.md](docs/07-backend-architecture.md) |
| 8 | AI Pipeline | [docs/08-ai-pipeline.md](docs/08-ai-pipeline.md) |
| 9 | Resume Parsing Pipeline | [docs/09-resume-parsing-pipeline.md](docs/09-resume-parsing-pipeline.md) |
| 10 | RAG Pipeline | [docs/10-rag-pipeline.md](docs/10-rag-pipeline.md) |
| 11 | Candidate Ranking Algorithm | [docs/11-candidate-ranking.md](docs/11-candidate-ranking.md) |
| 12 | Sequence Diagrams | [docs/12-sequence-diagrams.md](docs/12-sequence-diagrams.md) |
| 13 | Deployment Architecture | [docs/13-deployment-architecture.md](docs/13-deployment-architecture.md) |
| 14 | Implementation Roadmap | [docs/14-implementation-roadmap.md](docs/14-implementation-roadmap.md) |

## Technology Stack

| Layer | Choice |
|-------|--------|
| Frontend | Flutter (Material 3) |
| Backend | Python FastAPI |
| Relational DB | PostgreSQL |
| Vector DB | Qdrant |
| Embeddings | BAAI `bge-small-en-v1.5` (swappable) |
| OCR | Tesseract / PaddleOCR (fallback for scanned PDFs) |
| LLM | Provider abstraction: OpenAI, Gemini, Qwen, Llama, DeepSeek, any OpenAI-compatible endpoint |
| Async | Background workers (Celery/ARQ) + FastAPI BackgroundTasks for hot paths |

## Design Principles

- **Clean Architecture** with repository pattern and dependency injection (SOLID).
- **Provider abstractions** for `EmbeddingProvider`, `LLMProvider`, `VectorStore` so models and infra can be swapped without touching business logic.
- **Async processing** for resume pipelines and search.
- **Hallucination guard**: the LLM ranks only using retrieved chunks + structured profiles; every claim is traceable to a `chunk_id`.

## Getting Started (Design Review)

Read [docs/01-system-architecture.md](docs/01-system-architecture.md) first, then follow the numbered docs. The [implementation roadmap](docs/14-implementation-roadmap.md) proposes a staged delivery plan (MVP → production).
