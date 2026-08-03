# 05 — Clean Architecture Layers

## 1. Principle

The backend follows **Clean Architecture** with a strict **dependency rule**: source-code dependencies always point **inward**. `api → application → domain`, and `infrastructure` (adapters) implements interfaces owned by inner layers. Nothing in the inner layers knows about FastAPI, SQLAlchemy, Qdrant, or specific AI providers.

```
                    ┌───────────────────────────────┐
                    │        API LAYER (outer)      │  FastAPI routers, schemas, deps
                    │        http / ws / auth       │
                    └──────────────┬────────────────┘
                                   │ depends on
                    ┌──────────────▼────────────────┐
                    │     APPLICATION LAYER         │  Use cases, DTOs, ports
                    │  orchestration / business rules│
                    └──────────────┬────────────────┘
                                   │ depends on (ports/interfaces)
                    ┌──────────────▼────────────────┐
                    │        DOMAIN LAYER           │  Entities, value objects,
                    │  enterprise business rules     │  domain services
                    └──────────────┬────────────────┘
                                   │  no dependency on infra
        ┌──────────────────────────┼───────────────────────────────┐
        ▼                          ▼                               ▼
┌───────────────┐      ┌──────────────────────┐      ┌────────────────────────┐
│ INFRASTRUCTURE │      │   PERSISTENCE        │      │   EXTERNAL PROVIDERS    │
│ adapters       │      │ SQLAlchemy / PG       │      │ embedding / llm / ocr / │
│ implement ports│      │ Qdrant / Redis / S3   │      │ storage / pdf parsers    │
└───────────────┘      └──────────────────────┘      └────────────────────────┘
```

## 2. The Five Layers (hexagonal flavor)

| Layer | Responsibilities | Depends on |
|-------|------------------|-----------|
| **Domain** | Entities (`Candidate`, `Resume`, `Ranking`), value objects (`Email`, `DateRange`, `Score`), enums, domain services (`YearsExperienceCalculator`, `SkillNormalizer`, `HiddenGemRules`) | Nothing |
| **Application** | Use cases (each a class/function that orchestrates a single intent), DTOs, and **port interfaces** for repositories/providers | Domain only |
| **Infrastructure** | Adapters: PostgreSQL repositories, Qdrant store, Redis cache, provider clients (OpenAI/Gemini/Ollama/vLLM), OCR, object storage, task queue, observability | Implements application ports |
| **API** | HTTP routers, request validation (Pydantic), auth middleware, DI wiring via container | Application + infrastructure |
| **Configuration / DI** | Central `container.py` composes the object graph | All |

## 3. Dependency Injection

Single composition root: `app/core/container.py`.

```python
class Container:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.db_session = create_async_session_factory(settings.db)
        self.vector_store: VectorStore = VectorStoreFactory.create(settings.vector)   # Qdrant / pgvector
        self.embedding: EmbeddingProvider = EmbeddingFactory.create(settings.providers.embedding)
        self.llm: LLMProvider = LLMFactory.create(settings.providers.llm)
        self.ocr: OCRProvider = OCRFactory.create(settings.providers.ocr)
        self.storage: ObjectStorage = StorageFactory.create(settings.storage)

        # repositories implement domain/application interfaces
        self.candidate_repo = CandidateRepository(self.db_session)
        self.resume_repo = ResumeRepository(self.db_session)
        self.ranking_repo = RankingRepository(self.db_session)

        # use cases depend on interfaces, get wired here
        self.upload_resume = UploadResumeUseCase(self.resume_repo, self.storage, self.task_queue)
        self.process_resume = ProcessResumeUseCase(
            self.resume_repo, self.parser, self.ocr, self.structuring, self.chunker,
            self.embedding, self.vector_store, self.task_queue)
        self.search_candidates = SearchCandidatesUseCase(
            self.embedding, self.vector_store, self.candidate_repo, self.ranking_engine)
```

- **`app/api/deps.py`** exposes FastAPI `Depends` that resolve from the container per request.
- Tests replace real adapters with fakes implementing the same ports (no DB, no network).

## 4. Ports (owned by application)

```python
# application/ports.py
class CandidateRepository(Protocol):
    async def get(self, candidate_id: UUID) -> Candidate | None: ...
    async def save(self, candidate: Candidate) -> Candidate: ...
    async def delete(self, candidate_id: UUID) -> None: ...
    async def search(self, query: str, limit: int) -> list[Candidate]: ...

class VectorStore(Protocol):
    async def upsert(self, chunks: list[SemanticChunk], model: str, version: int) -> None: ...
    async def search(self, embedding: list[float], filters: dict, top_k: int) -> list[VectorHit]: ...
    async def delete_by_resume(self, resume_id: UUID) -> None: ...

class EmbeddingProvider(Protocol):
    async def embed(self, texts: list[str]) -> list[list[float]]: ...
    @property
    def model_name(self) -> str: ...
    @property
    def dimension(self) -> int: ...

class LLMProvider(Protocol):
    async def complete(self, system: str, user: str, *, json_mode: bool = False, temperature: float = 0.0) -> str: ...
    async def embed_texts(self, texts: list[str]) -> list[list[float]]: ...   # optional, some providers unify

class OCRProvider(Protocol):
    async def extract(self, image: bytes, lang: str = "eng") -> str: ...
```

Use cases receive these as constructor parameters. **The domain never sees them.**

## 5. SOLID Mapping

| Principle | Where applied |
|-----------|---------------|
| **S** | One use case per file; one adapter per provider; `SkillNormalizer` only normalizes skills. |
| **O** | New LLM/vector/embedding = new adapter class + factory registration; existing use cases unchanged. |
| **L** | Adapters faithfully implement port contracts; tests use fakes interchangeably. |
| **I** | Narrow ports: `EmbeddingProvider` has only embed-related methods; `LLMProvider` has only generation; `ObjectStorage` only storage. |
| **D** | API/application depend on abstractions (`CandidateRepository`, `VectorStore`), never on SQLAlchemy/Qdrant directly. |

## 6. Error Handling Across Layers

| Layer | Error strategy |
|-------|----------------|
| Domain | `ValueError`-style domain exceptions with explicit messages |
| Application | Maps domain failures → typed `AppError` (e.g., `ResumeNotFoundError`, `PipelineFailedError`) |
| API | Exception handlers translate `AppError` → RFC 7807 problem+json |
| Infrastructure | Retries + circuit breakers for external providers; DLQ for queue failures |

## 7. Testing Strategy by Layer

| Layer | Test | 
|-------|------|
| Domain | Pure unit tests (no IO) — years calculation, skill normalization, bucket classification |
| Application | Use case tests with fake repos/providers — assert orchestration + rules |
| Infrastructure | Adapter tests with real services (testcontainers for PG/Qdrant) |
| API | `httpx.AsyncClient` + TestClient against container with fakes (integration) |

## 8. Guarantees

- Replace Qdrant → pgvector: implement `VectorStore` adapter, switch config. **Zero domain/application changes.**
- Replace BAAI → OpenAI embeddings: new `EmbeddingProvider` adapter + factory. **Zero business logic changes.**
- Replace OpenAI → Gemini LLM: new `LLMProvider` adapter. **Ranking algorithm unchanged** (it only calls `llm.complete(json_mode=True)`).
