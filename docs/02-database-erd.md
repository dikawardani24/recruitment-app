# 02 — Database ERD

## 1. Overview

Two persistent stores:

1. **PostgreSQL** — system of record for all structured data (candidates, resumes, jobs, applications, rankings, audit).
2. **Qdrant** — vector index of semantic chunks. It holds **derived** data; the canonical source is PostgreSQL. Full re-index rebuilds Qdrant from PG.

## 2. Entity-Relationship Diagram

```
┌──────────────────────┐      ┌──────────────────────┐
│        users         │      │       resumes        │
├──────────────────────┤      ├──────────────────────┤
│ id UUID PK           │      │ id UUID PK           │
│ email VARCHAR UNIQUE │      │ candidate_id FK──┐   │
│ password_hash VARCHAR│      │ status ENUM      │   │
│ full_name VARCHAR    │      │ file_key VARCHAR │   │
│ role ENUM            │      │ file_name VARCHAR│   │
│   (applicant,        │      │ file_size BIGINT │   │
│    recruiter, admin) │      │ content_type VARCHAR │
│ created_at TIMESTAMP │      │ extracted_text TEXT  │
└──────────┬───────────┘      │ parsing_meta JSONB   │
           │ 1                 │ error_detail JSONB   │
           │                   │ embedding_model VARCHAR│
           │                   │ embedding_version INT  │
           │                   │ created_at / updated_at│
           │                   └────────────┬───────────┘
           │ 1                              │ N
           │                   ┌────────────┴───────────┐
           │                   │      candidates        │
           │                   ├────────────────────────┤
           │                   │ id UUID PK             │
           │                   │ user_id FK ────────────┤  (1:1 optional)
           │                   │ name VARCHAR           │
           │                   │ email VARCHAR          │
           │                   │ phone VARCHAR          │
           │                   │ location VARCHAR       │
           │                   │ summary TEXT           │
           │                   │ profile JSONB          │
           │                   │   (full structured      │
           │                   │    resume JSON,         │
           │                   │    normalized skills,   │
           │                   │    experience, education,│
           │                   │    certifications,       │
           │                   │    projects)             │
           │                   │ derived_metrics JSONB   │
           │                   │   (years_experience,    │
           │                   │    skill_count, ...)    │
           │                   │ status ENUM             │
           │                   │ created_at / updated_at │
           │                   └──────┬──────┬───────────┘
           │                          │ 1    │ 1
           │                   ┌──────┴──┐  ┌┴─────────────────┐
           │                   │ resumes │  │   candidate_     │
           │                   │ (above) │  │   skills         │
           │                   └─────────┘  ├──────────────────┤
           │                                │ id BIGSERIAL PK  │
           │                                │ candidate_id FK  │
           │                                │ skill_id FK      │
           │                                │ source ENUM      │
           │                                │   (parsed,       │
           │                                │    inferred)     │
           │                                │ confidence FLOAT  │
           │                                │ UNIQUE(candidate,│
           │                                │       skill)     │
           │                                └────────┬─────────┘
           │                                         │ N
           │                                ┌────────┴─────────┐
           │                                │      skills      │
           │                                ├──────────────────┤
           │                                │ id BIGSERIAL PK  │
           │                                │ name VARCHAR     │
           │                                │ canonical_name FK│
           │                                │ category VARCHAR │
           │                                │ aliases JSONB    │
           │                                └──────────────────┘
           │
           │ 1              ┌──────────────────────┐
           └────────────────┤        jobs          │
                            ├──────────────────────┤
                            │ id UUID PK           │
                            │ recruiter_id FK      │
                            │ title VARCHAR        │
                            │ company VARCHAR      │
                            │ description TEXT     │
                            │ requirements JSONB   │
                            │ embedding_model VARCHAR│
                            │ embedding_version INT │
                            │ status ENUM (draft,   │
                            │   published, closed)  │
                            │ created_at/updated_at │
                            └──────────┬───────────┘
                                       │ 1
                            ┌──────────┴───────────┐
                            │     applications     │
                            ├──────────────────────┤
                            │ id UUID PK           │
                            │ job_id FK            │
                            │ candidate_id FK      │
                            │ resume_id FK         │
                            │ status ENUM          │
                            │ created_at/updated_at│
                            └──────────┬───────────┘
                                       │ 1
                            ┌──────────┴───────────┐
                            │      rankings        │
                            ├──────────────────────┤
                            │ id UUID PK           │
                            │ application_id FK    │
                            │ job_id FK            │
                            │ candidate_id FK      │
                            │ bucket ENUM          │
                            │   (best, strong,     │
                            │    hidden_gem,       │
                            │    alternative)      │
                            │ overall_score FLOAT  │
                            │ skill_score FLOAT    │
                            │ experience_score FLOAT│
                            │ education_score FLOAT│
                            │ certification_score  │
                            │ strengths JSONB      │
                            │ weaknesses JSONB     │
                            │ explanation TEXT     │
                            │ recommendation TEXT  │
                            │ evidence JSONB       │
                            │   (chunk_ids used    │
                            │    by LLM)           │
                            │ model VARCHAR        │
                            │ created_at           │
                            │ UNIQUE(job, candidate,│
                            │        model, scope) │
                            └──────────────────────┘

┌────────────────────────┐       ┌────────────────────────┐
│   chunk_index_status   │       │    audit_logs          │
├────────────────────────┤       ├────────────────────────┤
│ id UUID PK             │       │ id BIGSERIAL PK        │
│ resume_id FK           │       │ actor_id UUID          │
│ status ENUM            │       │ action VARCHAR         │
│   (pending,indexed,    │       │ entity_type VARCHAR    │
│    failed)             │       │ entity_id UUID         │
│ vector_count INT       │       │ metadata JSONB         │
│ model VARCHAR          │       │ created_at TIMESTAMP   │
│ error_detail JSONB     │       └────────────────────────┘
│ created_at/updated_at  │
└────────────────────────┘
```

## 3. Table Definitions

### 3.1 `users`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | default gen_random_uuid() |
| email | VARCHAR(320) UNIQUE NOT NULL | |
| password_hash | VARCHAR(255) | null for SSO |
| full_name | VARCHAR(150) | |
| role | ENUM('applicant','recruiter','admin') | RBAC |
| created_at | TIMESTAMPTZ | default now() |

### 3.2 `candidates`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK → users.id NULL | optional link |
| name | VARCHAR(200) | extracted |
| email | VARCHAR(320) | extracted |
| phone | VARCHAR(50) | extracted |
| location | VARCHAR(200) | extracted |
| summary | TEXT | LLM-paraphrased summary |
| profile | JSONB NOT NULL | full structured resume JSON (see schema in doc 09) |
| derived_metrics | JSONB | years_experience, skill_count, avg_tenure, last_role_level |
| status | ENUM('new','screened','shortlisted','interview','hired','rejected') | |

### 3.3 `resumes`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| candidate_id | UUID FK → candidates.id | |
| status | ENUM('queued','parsing','ocr','structuring','chunking','indexing','indexed','failed') | pipeline state machine |
| file_key | VARCHAR | object-storage key |
| file_name | VARCHAR | original name |
| file_size | BIGINT | bytes |
| content_type | VARCHAR | |
| extracted_text | TEXT | cleaned text |
| parsing_meta | JSONB | pdf pages, ocr flag, char count |
| error_detail | JSONB | stage + message + retry count |
| embedding_model | VARCHAR | e.g. `BAAI/bge-small-en-v1.5` |
| embedding_version | INT | bump to trigger re-embed |

### 3.4 `skills` / `candidate_skills`
Normalized canonical skill taxonomy to avoid duplicate embeddings (`Docker` vs `docker`).
- `skills.name` is canonical; `aliases` stores variants seen on resumes.
- `candidate_skills.confidence` = LLM extraction confidence; `source` distinguishes explicitly listed vs inferred from experience text.

### 3.5 `jobs`
Stores job descriptions; embeddings for JD are stored in Qdrant under a `jobs` collection (or same collection with `entity_type=job`) for semantic candidate↔job matching.

### 3.6 `applications`
Links a candidate to a job via a resume. One candidate can apply to many jobs; one job has many applications.

### 3.7 `rankings`
Persisted, auditable output of the ranking engine. `UNIQUE(job_id, candidate_id, model, scope)` allows versioned re-ranking without clobbering history. `evidence` stores the chunk IDs and query that produced the LLM reasoning — the anti-hallucination audit trail.

### 3.8 `chunk_index_status`
Tracks vectorization state per resume so re-embedding (model/version upgrade) is a controllable background job.

### 3.9 `audit_logs`
Append-only record of sensitive actions (data export, deletion, profile edits).

## 4. Qdrant Collections (Vector DB)

### Collection `resume_chunks`
| Payload field | Type | Purpose |
|---------------|------|---------|
| candidate_id | UUID | filter / group |
| candidate_name | STRING | display |
| resume_id | UUID | provenance |
| section | STRING enum(skills,experience,projects,certifications,summary,education) | filter |
| chunk_id | UUID | idempotent upsert key |
| original_text | STRING | evidence for LLM + viewer |
| version | INT | embedding version |
| embedding_model | STRING | provenance |

- Distance: **Cosine** (bge models use cosine).
- Index: HNSW (m=16, ef_construct=200). Exact search only on small sets.

### Collection `job_descriptions`
Same payload shape with `entity_type=job`, `job_id`, `section=requirements|description`.

## 5. Indexing Strategy

| Index | Table | Columns |
|-------|-------|---------|
| PK | all | id |
| uq | users | email |
| uq | candidates | email (nullable unique) |
| ix | resumes | candidate_id, status |
| ix | candidate_skills | skill_id |
| ix | applications | job_id, candidate_id |
| ix | rankings | job_id, bucket |
| gin | candidates | profile, skills, summary |
| gin | resumes | extracted_text (tsvector for hybrid search) |
| ix | audit_logs | entity_id, created_at |

## 6. Consistency & Versioning

- **Resume re-index**: `embedding_version` bump → worker deletes points with old `version` for that `resume_id` → regenerates chunks → upserts → flips `chunk_index_status`.
- **Profile update**: any profile JSONB change marks candidate vectors `stale` and enqueues re-chunk+re-embed.
- **Source of truth**: PG only. Qdrant is rebuilt-able, and `chunk_index_status` makes this auditable and resumable.
