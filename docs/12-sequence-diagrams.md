# 12 — Sequence Diagrams

## 1. Resume Upload & Processing (Applicant Flow)

```
Applicant      Flutter App          API Gateway      Worker (pipeline)    PostgreSQL        Qdrant        Object Store        LLM/Embed
    │               │                    │                   │                  │              │             │                  │
    │  select PDF   │                    │                   │                  │              │             │                  │
    │──────────────▶│                    │                   │                  │              │             │                  │
    │               │ POST /resumes      │                   │                  │              │             │                  │
    │               │───────────────────▶│                   │                  │              │             │                  │
    │               │                    │── validate ──▶    │                  │              │             │                  │
    │               │                    │── store file ───────────────────────▶│             │             │                  │
    │               │                    │── insert resume(status=QUEUED) ───▶  │              │             │                  │
    │               │                    │── enqueue process_resume ──────────────▶│            │             │                  │
    │               │ 202 resume_id      │                   │                  │              │             │                  │
    │               │◀───────────────────│                   │                  │              │             │                  │
    │               │                    │                   │── update status=PARSING ──▶  │             │                  │
    │               │                    │                   │── fetch file ──────────────────────────────▶│                  │
    │               │                    │                   │── extract text (digital or OCR) ──────────────────▶  OCR       │
    │               │                    │                   │── update status=STRUCTURING ──▶ │             │                  │
    │               │                    │                   │── structure(profile schema) ──────────────────────────────▶  LLM │
    │               │                    │                   │── validate + normalize skills/date ──▶ candidate row      │      │
    │               │                    │                   │── update status=CHUNKING ──▶    │             │                  │
    │               │                    │                   │── chunk(profile)                │             │                  │
    │               │                    │                   │── embed(chunks) ──────────────────────────────────────────▶ Embed │
    │               │                    │                   │── update status=INDEXING ──▶    │             │                  │
    │               │                    │                   │── upsert(chunks+metadata) ──────────────────▶│                  │
    │               │                    │                   │── update status=INDEXED ──▶     │             │                  │
    │  poll status  │                    │                   │                  │              │             │                  │
    │◀────┬─────────│                    │                   │                  │              │             │                  │
    │     │GET status│                   │── read status ──▶ │                  │              │             │                  │
    │     │◀─────────│◀──────────────────│◀───────────────────│                  │              │             │                  │
    │  show "Indexed"│                  │                    │                  │              │             │                  │
```

## 2. Candidate Semantic Search & Ranking (Recruiter Flow)

```
Recruiter     Flutter App          API Gateway        Embedding        Qdrant          PostgreSQL        LLM Reasoner
    │              │                    │                  │               │                │                  │
    │  NL query    │                    │                  │               │                │                  │
    │─────────────▶│                    │                  │               │                │                  │
    │              │ POST /search/query │                  │               │                │                  │
    │              │───────────────────▶│                  │               │                │                  │
    │              │                    │── cache check ───│               │                │                  │
    │              │                    │── embed(query) ──▶│               │                │                  │
    │              │                    │                  │── search(top_k, filters) ──▶│                   │
    │              │                    │                  │                  │               │                │                  │
    │              │                    │                  │   hits(grouped by candidate)◀───│                  │
    │              │                    │                  │                  │               │                │                  │
    │              │                    │── hydrate profiles (candidate_ids) ──────────────▶│                  │
    │              │                    │                  │                  │   profiles + chunks◀───────────│                  │
    │              │                    │                  │                  │               │                │                  │
    │              │                    │── tier1 heuristic scoring (per candidate)          │                │                  │
    │              │                    │── tier2 LLM reasoning (evidence pack) ───────────────────────────────────▶│
    │              │                    │                  │                  │               │  strengths/weak/exp◀──│
    │              │                    │── validate evidence chunk_ids                      │                │                  │
    │              │                    │── assign buckets + persist ranking ──▶             │                │                  │
    │              │                    │                  │                  │               │                │                  │
    │              │  200 ranked results (buckets, scores, evidence)                        │                │                  │
    │              │◀───────────────────│                  │               │                │                  │
    │              │ show buckets + explanation + evidence drawer                           │                │                  │
    │◀─────────────│                    │                  │               │                │                  │
```

## 3. Re-Indexing on Embedding Model Upgrade

```
Operator/Admin       API Gateway      Worker          PostgreSQL          Qdrant
    │                    │               │                  │               │
    │ POST /admin/reindex/all (new version)                │               │
    │───────────────────▶│               │                  │               │
    │                    │── enqueue reindex tasks (batch) ──▶              │
    │                    │               │── for each resume:               │
    │                    │               │    read profile ───────────────▶ │
    │                    │               │    chunk + embed + upsert(version=V+1) ────▶│
    │                    │               │    update chunk_index_status=INDEXED ─▶│      │
    │                    │               │                  │               │
    │                    │               │── flip active version to V+1 ─▶  │
    │                    │               │── delete old-version vectors (batch) ─────────▶│
    │  202 accepted      │               │                  │               │
    │◀───────────────────│               │                  │               │
```

## 4. GDPR Right-to-Erasure (Candidate Deletion)

```
Recruiter/Admin      API Gateway       Application UC        PostgreSQL        Qdrant        Audit Log
    │                     │                   │                  │              │              │
    │ DELETE /candidates/{id}                │                  │              │              │
    │────────────────────▶│                   │                  │              │              │
    │                     │── load candidate ──────────────────▶│              │              │
    │                     │── delete vectors by candidate_id ────────────────────▶│              │
    │                     │── delete resume(s) + candidate rows ───▶              │              │
    │                     │── write audit_log (actor, entity) ─────────────────────────────────▶│
    │  204 No Content     │                   │                  │              │              │
    │◀────────────────────│                   │                  │              │              │
```

## 5. Compare Candidates (Dashboard)

```
Recruiter      Flutter App          API Gateway         Candidate Repo       LLM Reasoner
    │              │                    │                    │                  │
    │ select 2-4   │                    │                    │                  │
    │─────────────▶│                    │                    │                  │
    │              │ POST /compare {candidate_ids}          │                  │
    │              │───────────────────▶│                    │                  │
    │              │                    │── fetch profiles ─▶│                  │
    │              │                    │                    │── structured comparison ─▶│
    │              │                    │   side-by-side + AI summary ◀──────────│
    │              │  200 (profiles + comparison + summary)  │                  │
    │              │◀───────────────────│                    │                  │
    │  render comparison table + AI panel                    │                  │
    │◀─────────────│                    │                    │                  │
```

## 6. Failure Path: OCR Fallback + Retry

```
Worker
  │ extract_digital(text)
  │   └─ density low (< threshold)
  │         ├─ status=OCR
  │         ├─ rasterize pages
  │         ├─ OCR.extract(images) ──▶ Tesseract/PaddleOCR
  │         │        └─ low confidence? ── retry higher DPI (≤2)
  │         └─ merge text → continue pipeline
  │ structure(LLM) ── schema error
  │         ├─ retry with error feedback (≤2)
  │         └─ fallback rule-based extraction
  │               └─ still low confidence → status=FAILED(error_detail) → manual review queue
```

## 7. Search Caching & Fallback Path

```
API Gateway
  ├─ cache hit (query signature) ──▶ return cached ranked results immediately
  ├─ LLM timeout (> llm_timeout_ms)
  │     └─ return heuristic ranking with meta.reasoning="heuristic"
  └─ Qdrant unavailable
        └─ fail fast 503 + alert (never silently degrade candidate quality)
```
