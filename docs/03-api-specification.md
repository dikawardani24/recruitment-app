# 03 — API Specification

Base URL: `https://api.ats.example.com/v1`

- Auth: `Authorization: Bearer <JWT>` for all endpoints except `POST /auth/*`.
- Content-Type: `application/json`.
- Errors: RFC 7807 problem+json envelope `{ "type", "title", "status", "detail", "instance" }`.
- Async operations return `202 Accepted` with `Location` header polling URL.

## 1. Common Schemas

### Envelope
```json
{
  "data": { },
  "meta": { "page": 1, "limit": 20, "total": 142 },
  "errors": null
}
```

### Resume Status
`QUEUED → PARSING → OCR → STRUCTURING → CHUNKING → INDEXING → INDEXED | FAILED`

## 2. Authentication (`/auth`)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Exchange credentials → `{access_token, refresh_token, user}` |
| POST | `/auth/refresh` | Rotate refresh token |
| POST | `/auth/logout` | Revoke token |
| GET | `/auth/me` | Current user |

`POST /auth/login`
```json
// req
{ "email": "alice@acme.com", "password": "***" }
// 200
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 1800,
  "user": { "id": "uuid", "email": "alice@acme.com", "role": "recruiter" }
}
```

## 3. Resumes (`/resumes`) — Applicant Flow

### POST `/resumes/upload`
`multipart/form-data`: `file` (PDF ≤ 10 MB).
→ `202`
```json
{ "resume_id": "uuid", "status": "QUEUED", "poll_url": "/v1/resumes/uuid" }
```

### GET `/resumes/{resume_id}`
→ `200`
```json
{
  "resume_id": "uuid",
  "candidate_id": "uuid",
  "status": "INDEXED",
  "file_name": "dev.pdf",
  "embedding_model": "BAAI/bge-small-en-v1.5",
  "embedding_version": 3,
  "parsing_meta": { "pages": 2, "used_ocr": true },
  "error_detail": null
}
```

### GET `/resumes/{resume_id}/text`
Raw cleaned text (recruiter/admin only).

### GET `/resumes/{resume_id}/file`
Streams original PDF (resume viewer).

### GET `/candidates/{candidate_id}/resumes`
List candidate's resume versions.

## 4. Candidates (`/candidates`)

### GET `/candidates`
Query params: `q`, `status`, `skill`, `location`, `page`, `limit`.
→ list of `{candidate_id, name, email, location, headline, status, skill_count, years_experience}`

### GET `/candidates/{id}`
Full structured profile:
```json
{
  "candidate": { "name": "Jane Doe", "email": "jane@x.com", "phone": "+1...", "location": "Berlin" },
  "summary": "Senior Flutter developer with 6 years...",
  "skills": ["Flutter", "Dart", "Firebase", ...],
  "experience": [
    { "company": "BankCo", "position": "Senior Flutter Engineer",
      "start_date": "2020-03", "end_date": "2024-06",
      "responsibilities": ["Led mobile payments team", "..."] }
  ],
  "education": [{ "institution": "...", "degree": "BSc CS", "field": "Computer Science", "year": 2016 }],
  "certifications": ["AWS Developer Associate"],
  "projects": [{ "name": "...", "description": "...", "url": "...", "highlights": ["..."] }]
}
```

### GET `/candidates/{id}/chunks`
Return semantic chunks with section + text (evidence drill-down for recruiters).

### DELETE `/candidates/{id}`
Right-to-erasure: deletes PG rows + Qdrant points (GDPR). Audit log entry.

## 5. Search (`/search`) — Recruiter Flow

### POST `/search/query`
```json
// req
{
  "query": "Find Senior Flutter Developers with banking experience",
  "job_id": "optional-uuid",
  "filters": { "skills": ["Flutter"], "min_years": 2, "location": "Berlin" },
  "top_k": 50,
  "candidate_count": 20
}
```
→ `200`
```json
{
  "query_id": "uuid",
  "results": [
    {
      "candidate_id": "uuid",
      "candidate_name": "Jane Doe",
      "bucket": "best",
      "overall_score": 0.91,
      "scores": {
        "skill_match": 0.94,
        "experience_match": 0.88,
        "education_match": 0.80,
        "certification_match": 0.70
      },
      "strengths": ["6 yrs Flutter", "banking payments domain", "team lead"],
      "weaknesses": ["No AI/ML experience", "Certifications light"],
      "explanation": "Ranked best: matches 5/6 required skills and has direct banking payments experience (chunks c-1..c-4).",
      "recommendation": "Interview first; probe leadership depth.",
      "evidence": [
        { "chunk_id": "uuid", "section": "experience", "score": 0.93,
          "text": "Led mobile payments team at BankCo..." }
      ]
    }
  ],
  "buckets": { "best": 5, "strong": 7, "hidden_gem": 4, "alternative": 4 },
  "meta": { "model": "gpt-4o", "embedding_model": "bge-small-en-v1.5", "latency_ms": 812 }
}
```

### POST `/search/job`
Match a **job description** to candidates (hidden-gem discovery for a role). Accepts `job_id` or an uploaded JD → runs JD embedding → same ranking pipeline.

### GET `/search/results/{query_id}`
Fetch persisted ranking result (pagination over bucket).

## 6. Jobs & Applications

| Method | Path | Description |
|--------|------|-------------|
| POST | `/jobs` | Create JD (embeds requirements) |
| GET | `/jobs` | List (recruiter) |
| GET | `/jobs/{id}` | Detail + requirements |
| PATCH | `/jobs/{id}` | Update (re-embed on change) |
| DELETE | `/jobs/{id}` | Delete |
| POST | `/jobs/{id}/rank` | Trigger ranking for this job → list of ranked candidates |
| GET | `/jobs/{id}/rankings` | Persisted ranked candidates |
| POST | `/applications` | Applicant applies with resume_id → application |
| GET | `/applications?job_id=` | Recruiter inbox |
| PATCH | `/applications/{id}` | Update status |

## 7. Dashboard

| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard/summary` | Counts by status, pipeline health |
| POST | `/compare` | `{candidate_ids:[...]}` → side-by-side comparison w/ AI summary |
| GET | `/dashboard/analytics` | (future) hiring funnel metrics |

## 8. Admin & Ops

| Method | Path | Description |
|--------|------|-------------|
| GET | `/admin/pipeline/health` | Queue depth, worker status, provider health |
| POST | `/admin/reindex/{resume_id}` | Force re-chunk+re-embed |
| POST | `/admin/reindex/all` | Full rebuild (batch, versioned) |
| POST | `/admin/providers/validate` | Test current embedding/LLM config |

## 9. Error Codes (subset)

| Status | Code | Meaning |
|--------|------|---------|
| 400 | `INVALID_FILE_TYPE` | Non-PDF upload |
| 400 | `FILE_TOO_LARGE` | > 10 MB |
| 401 | `UNAUTHORIZED` | Missing/expired token |
| 403 | `FORBIDDEN` | Wrong role |
| 404 | `NOT_FOUND` | Resource missing |
| 409 | `CONFLICT` | Duplicate application |
| 422 | `VALIDATION_ERROR` | Schema violation |
| 429 | `RATE_LIMITED` | Quota exceeded |
| 500 | `PIPELINE_ERROR` | Worker pipeline failure (retryable) |

## 10. Versioning & Conventions

- Path versioning (`/v1`). Breaking changes → `/v2` with sunset header.
- All list endpoints paginated (`page`, `limit` ≤ 100) and sortable.
- Idempotency: `POST /search/query` returns `query_id`; re-POST with same idempotency-key returns cached result.
- OpenAPI 3.1 generated from code; published at `/v1/openapi.json`.
