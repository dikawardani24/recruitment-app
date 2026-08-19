# Backend Developer — Sample Dataset

Sample dataset for exercising **JD processing → CV extraction → relevance
detection → ranking** for a **Backend Developer** role. All people, companies,
and contacts are fictional.

```
backend_developer/
├── job_description.txt
├── README.md
└── cvs/
    ├── candidate_01_python_backend_developer.pdf
    ├── candidate_02_python_backend_junior.pdf
    ├── candidate_03_fullstack_developer.pdf
    ├── candidate_04_java_developer.pdf
    └── candidate_05_graphic_designer.pdf
```

## How to run it

Create a job with the JD file (`POST /api/jobs`, `jd_file=job_description.txt`),
import the five PDFs (`POST /api/jobs/{id}/candidates/import`), then rank
(`POST /api/jobs/{id}/rank`). Or run the pipeline directly as in
`../flutter_developer/README.md` (swap the folder path).

## Job description

Parsed requirements: `required_skills = [python, sql, fastapi, rest,
postgresql, docker, git, microservices, …]`, `min_years = 3`, `education = bsc`.
The JD targets Python/FastAPI; its required skills are deliberately not the full
TECH_SKILLS vocabulary (e.g. `api design` is open-vocabulary).

## Candidates — intended vs verified

Exact numeric scores for normal-ranking candidates are intentionally not
listed; only classification/relevance and the verified ranking order.

| # | Candidate (fictional) | Profile | Intended | Verified | Meets JD | Relevance |
|---|-----------------------|---------|----------|----------|----------|-----------|
| 01 | Bayu Nugroho Santoso | Python/FastAPI dev, 5+ yrs — Python/FastAPI/PostgreSQL/REST/Docker/Git, AWS, CI/CD, microservices | `MET` | `MET` | yes | `RELEVANT` |
| 02 | Dewi Anggraini | Python/FastAPI dev, 1.5 yrs — Python/FastAPI/PostgreSQL/REST/Git (no Docker, no cloud) | `MET`/`PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 03 | Farhan Maulana | Fullstack dev, 4 yrs — Python/Django/React/Node/REST/PostgreSQL/Git | `PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 04 | Joko Prasetyo | Java/Spring dev, 4+ yrs — Java/Spring Boot/MySQL/REST/Microservices | `PARTIALLY_MET`/`NOT_MET` | `MET` | yes | `RELEVANT` |
| 05 | Bella Safitri | Graphic Designer, 6 yrs — Photoshop/Illustrator/InDesign, print & branding | `NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |

Verified ranking order: `01 > 03 > 04 > 02 > 05`, with 05 pinned to the bottom
at `score = 0`.

Note: 02 (junior, core-stack match) ranks below the fullstack and Java devs.
This follows from the 3-year minimum and experience weighting — the Java dev has
4+ years and a cert, while 02 has only 1.5 years and no Docker/cloud, which
pushes its score below the adjacent but more experienced profiles.

## Why each candidate gets its classification

- **01 (strong)** — matches nearly all required and preferred skills
  (Python, SQL, FastAPI, REST, PostgreSQL, Docker, Git, microservices, AWS,
  CI/CD). `MET`, top.
- **02 (junior)** — correct core stack (Python, FastAPI, PostgreSQL, REST, Git,
  SQL) but junior experience and missing Docker/cloud/microservices. `MET` but
  ranked last among the relevant candidates.
- **03 (fullstack)** — shares the `backend` and `software` domains and matches
  several required skills (Python, SQL, REST, PostgreSQL, Git), so the gate
  returns `RELEVANT`/`MET` even though it is a fullstack rather than a dedicated
  backend profile. Ranks third.
- **04 (Java)** — strong backend experience but the wrong stack. It still
  matches required skills (SQL, REST, microservices) and shares the `backend`
  domain, so the gate classifies it `RELEVANT`/`MET`.
- **05 (Graphic Designer)** — intentionally **unrelated** (design domain, zero
  required-skill matches). Must be `NOT_MET` with `score = 0` and bottom of the
  ranking, despite 6 years of experience.

## Intentionally unrelated candidate (negative test)

`candidate_05_graphic_designer.pdf`:

```
Designer CV + Backend JD → UNRELATED → NOT_MET → score = 0 → bottom
```

It never receives a normal score: all sub-scores are forced to `0`, it is not
passed to LLM scoring, and the sort key places it below every relevant candidate.

## Cross-job behavior

| CV | Job | Verified |
|----|-----|----------|
| candidate_01_python_backend_developer.pdf | Backend JD | `MET` |
| candidate_01_python_backend_developer.pdf | UI/UX JD | `NOT_MET` |
| candidate_01_data_analyst.pdf (Data job) | Backend JD | `MET` (matches `python`/`sql` → 2+ required) |

## Observed behavior / known divergences

- **Any same-domain backend/fullstack developer is `MET`.** The gate
  (`app/ranking/_relevance.py`) returns `RELEVANT` when a candidate shares the
  job's professional domain or matches 2+ required skills. The fullstack (03)
  and Java (04) profiles are therefore `MET`, not `PARTIALLY_MET`. This job has
  no `PARTIALLY_MET` candidate in the dataset.
- **Stack mismatch is under-weighted.** A Java developer (04) can be classified
  `MET` for a Python/FastAPI role and outrank the matching junior (02) purely via
  experience — the relevance gate ignores required-skill *coverage*.
- **Open-vocabulary JD terms** (`api design`) appear in `required_skills`; they
  are unmatchable by dictionary-based CV extraction but show up in `skill_gaps`.
- **Reproducibility:** verified with `Settings(llm_api_key=None)` (rules-based).
  With an API key, the LLM also re-scores relevant candidates, so exact scores
  vary.