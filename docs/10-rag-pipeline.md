# 10 — RAG Pipeline

## 1. Overview

Retrieval-Augmented Generation grounds the ranking LLM in **retrieved evidence** so it reasons over the candidate's actual resume, never from memory. Everything is traceable: every LLM claim maps to a chunk.

## 2. Indexing Side (write path)

```
structured profile (JSONB) ──▶ chunker ──▶ chunks ──▶ embed ──▶ Qdrant upsert
```

### 2.1 Semantic Chunking (`chunker.py`)
Chunks are derived from the **structured profile**, not raw text, keeping each chunk semantically homogeneous:

| Section | Chunk unit | Example |
|---------|-----------|---------|
| skills | 1 chunk per candidate (compact) OR grouped by category | `["Flutter","Dart","Firebase"]` |
| experience | 1 chunk per role (company + position + responsibilities + dates) | BankCo / Senior Flutter Engineer |
| projects | 1 chunk per project | openbank-flutter-sdk |
| certifications | 1 chunk (grouped) | AWS, Google Mobile |
| summary | 1 chunk | professional summary |
| education | 1 chunk | TU Berlin BSc CS |

Chunk text template (experience):
```
Experience — BankCo
Senior Flutter Engineer (2020-03 to 2024-06)
• Led mobile payments squad of 4 engineers.
• Migrated legacy app to Flutter 3 with 40% crash reduction.
```

### 2.2 Chunk metadata (required payload, doc 02 §4)
```
candidate_id, candidate_name, resume_id,
section ∈ {skills, experience, projects, certifications, summary, education},
chunk_id (UUID — idempotency key), original_text, version, embedding_model
```

### 2.3 Indexing invariants
- Upsert is **idempotent** on `chunk_id`.
- Re-index = delete by `(resume_id, version<current)` → upsert → flip `chunk_index_status`.
- Mixed-model safety: vectors tagged with `embedding_model` + `version`; search filters on active version.

## 3. Retrieval Side (query path)

```
query ──▶ embed(query) ──▶ Qdrant search(top_k, filters) ──▶ group by candidate ──▶ hydrate profiles
```

### 3.1 Query processing
1. Query embedding with **bge instruction prefix** (doc 08 §5) at query-time only.
2. Vector search `top_k` (default 50) with payload filters from the request (`skills`, `min_years`, `location`, `section`).
3. **Group hits by `candidate_id`**; keep per-candidate top-N section diversity (avoid 10 experience chunks drowning out a strong project chunk).
4. Score aggregation per candidate: weighted max/mean of chunk similarities.

### 3.2 Hybrid retrieval (optional, for hard queries)
When pure vector recall is low (rare skill names), supplement with **BM25** over `resumes.extracted_text` (Postgres `tsvector`). Fuse via Reciprocal Rank Fusion (RRF):

```
final_score(c) = Σ_{retrievers r} 1 / (k + rank_r(c)) , k=60
```

Vector-only is default; hybrid is toggled by `search.hybrid=true`.

## 4. Candidate Context Assembly (for LLM)

Each candidate gets a **bounded evidence pack**:

```json
{
  "candidate_id": "uuid",
  "name": "Jane Doe",
  "profile": { "summary": "...", "skills": [...], "years_experience": 7.2 },
  "evidence": [
    { "chunk_id": "c-1", "section": "experience", "score": 0.93,
      "text": "Led mobile payments squad at BankCo..." },
    { "chunk_id": "c-7", "section": "projects", "score": 0.88,
      "text": "openbank-flutter-sdk..." }
  ]
}
```

Budget guard: max N chunks (e.g. 8) and max tokens per candidate so ranking stays fast and fair across candidates.

## 5. Job Description Matching (RAG for JD)

`POST /search/job`: JD text is chunked (requirements + description) and embedded; each JD chunk queries the resume index; results aggregated per candidate — powers "who is the best candidate for this job description?".

## 6. Hallucination Guard (retrieval-side)

- **Evidence constraint**: reasoning LLM must set `evidence.chunk_ids ⊆ retrieved_chunk_ids`. Post-validation rejects explanations referencing unknown chunks.
- **Only retrieved info**: profiles + evidence are the *only* candidate facts the LLM sees; it cannot add external knowledge about the candidate.
- **Score transparency**: LLM-reasoned scores are blended but the raw retrieval scores remain visible in the response (`scores.*`).
- **Attribution UI**: chunk evidence is returned so the recruiter can verify (doc 06 §7).

## 7. Caching

| Cache | Key | TTL |
|-------|-----|-----|
| Search result | sha256(normalized query + filters + model versions) | 5 min |
| Profile by id | candidate_id | 10 min |
| Query embedding | sha256(query) | 24 h |

Invalidation: profile/vector changes bump cache keys by including `embedding_version` and a `profile_version` counter.

## 8. Monitoring

- Retrieval metrics: recall@10 (against labeled golden queries), latency p50/p95, Qdrant point counts by collection.
- LLM usage: tokens per ranking call, cache hit rate.
- Quality: manual-relevance feedback from recruiters ("mark relevant/irrelevant") logged to train future retrieval evals.
