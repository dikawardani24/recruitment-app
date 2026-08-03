# 01 — Complete System Architecture

## 1. Overview

The system is a **two-actor, event-driven, retrieval-augmented** platform:

- **Applicant flow**: resume upload → parsing → LLM structuring → relational storage → semantic chunking → embedding → vector indexing.
- **Recruiter flow**: natural-language search → embedding → vector retrieval → profile hydration → LLM reasoning → ranked candidate set.

Both flows share one core: a **candidate knowledge base** composed of a PostgreSQL relational store (ground truth) and a Qdrant vector store (semantic index). The LLM is always used as a **reasoner constrained by retrieved evidence**, never as a free-form knowledge source.

## 2. High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             FLUTTER CLIENT (Material 3)                     │
│  Applicant Portal        Recruiter Dashboard        Resume Viewer           │
└───────────────┬────────────────────────────────────────────┬────────────────┘
                │ HTTPS (REST/JSON)                           │
                ▼                                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FASTAPI GATEWAY / API LAYER                       │
│  auth          resumes         candidates         search          jobs      │
│  ranking       admin           ws/notifications                            │
└──────┬──────────────────────────────┬───────────────────────────┬───────────┘
       │                              │                           │
       ▼ async                       ▼                            ▼
┌───────────────┐        ┌──────────────────────┐      ┌──────────────────────┐
│ WORKER (API)  │        │   RESUME PIPELINE    │      │     SEARCH PIPELINE   │
│ background    │        │  (worker process)    │      │  (synchronous in API) │
│ tasks         │        │  1 parse  2 structure│      │  1 embed   2 retrieve │
│ email, notify │        │  3 chunk  4 embed    │      │  3 hydrate 4 rank     │
└───────────────┘        └──────────┬───────────┘      └──────────┬───────────┘
                                    │                             │
              ┌─────────────────────┼─────────────────────────────┼─────────────┐
              │                     ▼                             ▼             │
              │    ┌───────────────────────────┐      ┌──────────────────────┐  │
              │    │        POSTGRESQL          │      │       QDRANT          │  │
              │    │ candidates, resumes,       │◄────►│ chunks + embeddings  │  │
              │    │ jobs, applications,        │      │ (metadata-rich)      │  │
              │    │ rankings                   │      └──────────────────────┘  │
              │    └───────────────────────────┘                                 │
              └──────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
              ┌────────────────────────────────────────────┐
              │  EXTERNAL PROVIDERS (via abstraction ports) │
              │  EmbeddingProvider  LLMProvider  OCRProvider │
              └────────────────────────────────────────────┘
```

## 3. Core Services

### 3.1 API Gateway (FastAPI)
- REST endpoints for applicants, recruiters, jobs, dashboards.
- Authentication (JWT), authorization (RBAC), rate limiting.
- Thin controllers — all business logic lives in use cases.

### 3.2 Resume Processing Pipeline (async worker)
Stages (detailed in doc 09):
1. File validation & virus scan
2. PDF text extraction (digital) → OCR fallback (scanned)
3. Text cleaning
4. Section detection & normalization
5. **LLM structuring** → JSON profile (doc 08)
6. Validation & entity linking (skills → canonical taxonomy)
7. Persistence to PostgreSQL
8. Semantic chunking (doc 10)
9. Embedding generation
10. Vector upsert to Qdrant
11. Status events emitted (queued → processing → indexed / failed)

### 3.3 Search & Ranking Service (synchronous, cached)
- Query embedding
- Vector retrieval (top-K with score threshold + metadata filters)
- Profile hydration from PostgreSQL
- **Ranking engine** (doc 11): hybrid lexical + semantic + heuristic + LLM reasoning
- Ranking persisted for auditability; cached per query signature

### 3.4 Dashboard Aggregation Service
- Job descriptions, candidate comparison, AI recommendations, resume viewer (served from stored PDF).

## 4. Data Flows

### 4.1 Applicant Upload Flow
```
Upload(PDF) → [API] → s3/object store + DB row(status=QUEUED)
  → [Worker] extract → OCR? → clean → detect sections
  → [LLM] structure → validate → save structured profile
  → chunk → embed → upsert vectors → DB status=INDEXED
  → notify applicant (websocket/email)
```

### 4.2 Recruiter Search Flow
```
Query text → embed(query) → Qdrant search(topK, filters)
  → distinct candidate ids → hydrate profiles from PG
  → ranking engine (heuristics + LLM reasoning over evidence)
  → return ranked buckets: best | strong | hidden gem | alternative
```

## 5. Cross-Cutting Concerns

| Concern | Approach |
|---------|----------|
| Security | JWT + RBAC, upload size/type limits, virus scan, secrets in Vault/SSM, CSP, HTTPS/TLS everywhere |
| Privacy/Compliance | GDPR-ready: right-to-erasure deletes PG row + Qdrant points; data retention policy; audit logs |
| Observability | Structured JSON logs, OpenTelemetry traces, metrics (Prometheus), Sentry for errors |
| Reliability | Retries + idempotency keys for pipeline steps, DLQ for failed events, circuit breakers on LLM/vector calls |
| Performance | Async workers, connection pooling, vector HNSW config, caching of hot profiles/embeddings |
| Configurability | `settings.yaml` / env-driven; providers swapped by config, not code |

## 6. Provider Abstraction (Swap Without Code Change)

```
                    ┌────────────────────────────┐
                    │   Domain Ports (interfaces) │
                    ├────────────────────────────┤
                    │ EmbeddingProvider          │
                    │ LLMProvider                │
                    │ VectorStore                │
                    │ OCRProvider                │
                    │ ObjectStorage              │
                    │ FileParser (pdf/docx)      │
                    └────────────┬───────────────┘
                                 │ adapters
        ┌────────────────────────┼────────────────────────────┐
        ▼                        ▼                            ▼
  QdrantVectorStore      OpenAIEmbedding            OpenAILLM
  pgvectorVectorStore    GeminiEmbedding           GeminiLLM
                         LocalBGEEmbedding (ONNX)  OllamaLLM (Llama/Qwen/DeepSeek)
                                                  vLLM (OpenAI-compatible)
```

- Selected via `settings.providers.embedding = "bge-small-en-v1.5"` etc.
- Business logic depends only on ports. Adding a new provider = add an adapter, register in DI container.

## 7. Non-Functional Requirements

- **Availability**: 99.9% target; stateless API behind LB; workers scale horizontally.
- **Latency**: search p95 < 2s (excluding cold model loads); upload processed < 60s typical.
- **Scalability**: batch resizes of Qdrant replicas; PG read replicas; worker autoscaling on queue depth.
- **Data durability**: object storage with versioning; PG daily snapshots + WAL archiving; Qdrant snapshots.

## 8. Security Boundaries

1. **Public**: Flutter → API (TLS, JWT).
2. **Private**: API → PG, Qdrant, object storage (VPC private subnets).
3. **External**: API/workers → LLM/embedding/OCR providers via secrets + IP allowlists where possible.
