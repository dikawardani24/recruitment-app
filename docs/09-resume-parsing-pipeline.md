# 09 — Resume Parsing Pipeline

## 1. Goal

Transform an uploaded PDF into a **validated, normalized, structured profile** — not just extracted text. This is the critical differentiator of the system.

```
PDF ──▶ extract ──▶ clean ──▶ section detect ──▶ normalize ──▶ LLM structure ──▶ validate ──▶ store + index
        │
        └─(scanned)─▶ OCR fallback
```

## 2. Pipeline Stages

### Stage 0 — Validation & Ingest
- Accept PDF only (magic-byte check + size ≤ 10 MB).
- Virus scan (ClamAV) in worker.
- Hash file → idempotency (duplicate returns existing `resume_id`).
- Store original PDF in object storage; create `resumes` row `status=QUEUED`.

### Stage 1 — Text Extraction (digital)
- Primary: **pdfplumber / pypdf** (layout-aware; preserves line structure).
- Metrics: character count, text density per page.
- **Decision point**: if text density < threshold (`min_text_density`, e.g. < 200 chars/page) → treat as scanned → **Stage 1b**.

### Stage 1b — OCR Fallback (scanned PDF)
- Rasterize pages (PyMuPDF) at ~200–300 DPI.
- Tesseract/PaddleOCR (configurable `OCRProvider`) with language config.
- Merge page texts; mark `parsing_meta.used_ocr=true`.
- PaddleOCR offers layout/table awareness → better for structured resumes.

### Stage 2 — Text Cleaning
- Normalize unicode, whitespace, hyphenation artifacts.
- Remove headers/footers/page numbers, URLs noise.
- Preserve line breaks + paragraph boundaries (structure hints for section detection).

### Stage 3 — Section Detection & Normalization
Two-pass approach:

**Pass A (rule-based fast path)** — regex/header matching over common resume sections:
```
Section  Aliases (normalized → canonical)
CONTACT  name, email, phone, location, linkedin, github
SUMMARY  professional summary, profile, about me, objective
SKILLS   technical skills, core competencies, technology stack, tools
EXPERIENCE work experience, employment history, professional experience
EDUCATION academic background, education history
CERTIFICATIONS certificates, licenses, credentials
PROJECTS projects, personal projects, open source
LANGUAGES languages, spoken languages
```

**Pass B (LLM-assisted, when Pass A confidence low)** — for non-standard formats, the structuring LLM (doc 08 §4) simultaneously performs section classification + field extraction. Rule-based headers are passed as hints.

### Stage 4 — LLM Structuring
- Prompt with strict JSON schema + few-shot examples + Pass A hints.
- `temperature=0`, `json_mode=True`.
- Output = `CandidateProfile` (schema below).

### Stage 5 — Validation & Normalization (code, deterministic)
| Check | Action |
|-------|--------|
| Required fields | `candidate.email`, `name` present, else flag for manual review |
| Date parsing | all dates → `YYYY-MM`; `Present` → `null`; invalid → drop + log |
| Date coherence | start ≤ end; overlapping employers → keep both, flag |
| Skill canonicalization | map aliases → canonical via taxonomy (Docker/docker/dockers → `docker`); link `candidate_skills` |
| Experience calc | `YearsExperienceCalculator` from date ranges |
| Duplicate fields | dedupe skills, projects, certifications |
| PII sanity | email/phone format validation |

### Stage 6 — Persist + Index
- Save `profile` JSONB + `derived_metrics` → PG.
- Chunk (doc 10) → embed → upsert vectors.
- Set `status=INDEXED`.

## 3. Failure Handling

| Failure | Handling |
|---------|----------|
| Not a PDF / corrupt | `400 INVALID_FILE_TYPE` / mark FAILED with detail |
| Empty OCR result | retry OCR with higher DPI → else FAILED "unreadable document" |
| LLM structuring schema error | retry (≤ 2) with error message fed back → fallback to rule-based extraction → else FAILED for manual review |
| Low confidence extraction | mark `candidate.status=needs_review`, still index (better to surface than drop) |

## 4. Structured Profile Schema (contract shared by LLM + DB + API)

```json
{
  "candidate": {
    "name": "Jane Doe",
    "email": "jane.doe@email.com",
    "phone": "+1 555 0100",
    "location": "Berlin, Germany"
  },
  "summary": "Senior Flutter developer with 6 years building fintech mobile apps.",
  "skills": ["Flutter", "Dart", "Firebase", "REST APIs", "CI/CD", "SQL"],
  "experience": [
    {
      "company": "BankCo",
      "position": "Senior Flutter Engineer",
      "start_date": "2020-03",
      "end_date": "2024-06",
      "responsibilities": [
        "Led mobile payments squad of 4 engineers.",
        "Migrated legacy app to Flutter 3 with 40% crash reduction."
      ]
    }
  ],
  "education": [
    { "institution": "TU Berlin", "degree": "Bachelor of Science", "field": "Computer Science", "start_year": 2012, "end_year": 2016 }
  ],
  "certifications": ["AWS Certified Developer – Associate", "Google Mobile Web Specialist"],
  "projects": [
    { "name": "openbank-flutter-sdk", "description": "Open-source SDK...", "url": "https://github.com/jane/...", "highlights": ["700+ GitHub stars", "Used by 3 banks"] }
  ]
}
```

## 5. Derived Metrics (computed post-validation)

```json
{
  "years_experience": 7.2,
  "total_roles": 4,
  "avg_tenure_years": 1.8,
  "fast_promotion_signal": true,
  "skill_count": 24,
  "leadership_signals": 3,
  "opensource_signals": 2,
  "top_industries": ["fintech", "mobile"]
}
```
These feed the **hidden-gem detector** (doc 11) and are shown on the recruiter dashboard.

## 6. Parsing Quality Metrics (observability)

Per resume, record in `parsing_meta`:
- `used_ocr`, `pages`, `chars`, `cleaned_chars`
- `section_detection`: map of detected sections + confidence
- `extraction_confidence` (LLM self-reported)
- `validation_warnings[]`
These feed a **pipeline quality dashboard** (rate of OCR fallback, schema failures, manual-review flags).

## 7. Schema Versioning

`profile_schema_version` stored on `candidates`; migration jobs re-run Stage 4 on old resumes when schema changes (batch, throttled).
