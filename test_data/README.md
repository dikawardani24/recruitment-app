# test_data — Sample Jobs & CV Dataset

Ready-to-run dataset for exercising the recruitment pipeline **end-to-end**:
JD processing → CV text extraction → profile extraction → **job-relevance gate**
→ ranking. All people, companies, and contacts are **fictional**.

```
test_data/
├── flutter_developer/        # Junior Flutter Developer
├── backend_developer/        # Backend Developer (Python/FastAPI)
├── ui_ux_designer/           # UI/UX Designer
├── data_analyst/             # Data Analyst
├── hr_recruiter/             # HR Recruiter
└── verify_dataset.py         # read-only pipeline check over all 5 jobs
```

Each job folder contains:

- `job_description.txt` — the JD to create a job from (`POST /api/jobs`,
  `jd_file=...`).
- `README.md` — per-job expected vs verified results, per-candidate rationale,
  and observed gate behavior.
- `cvs/*.pdf` — **five unique CV PDFs** (25 CVs total), generated with weasyprint
  and verified extractable by pdfplumber.

## Candidate distribution (per job)

| # | Intent | Verified behaviour |
|---|--------|--------------------|
| c1 | strong match | `MET` / `RELEVANT` — top of ranking |
| c2 | good match | `MET` / `RELEVANT` |
| c3 | related (same domain) | `MET` / `RELEVANT` (gate treats same-domain candidates as relevant) |
| c4 | weak/adjacent (cross-domain) | `PARTIALLY_MET` / `PARTIALLY_RELEVANT` (3 of 5 jobs) |
| c5 | **unrelated** (accountant, graphic designer, backend dev, HR recruiter, Flutter dev) | `NOT_MET`, `score = 0`, pinned to the bottom |

Every `c5` is an **intentional negative test**: zero required-skill matches and
no professional-domain overlap, so the hard relevance gate
(`app/ranking/_relevance.py`) forces `score = 0`, skips all scoring, and sorts
it below every relevant candidate — even when it has more years of experience.

## Verified results (rules-based)

Reproduced with `Settings(llm_api_key=None)`; see `verify_dataset.py`.

| Job | `MET` | `PARTIALLY_MET` | `NOT_MET` (score 0, bottom) |
|-----|-------|-----------------|------------------------------|
| Flutter Developer | c1 Flutter, c2 Flutter, c3 Android | c4 Java | c5 Accountant |
| Backend Developer | c1 Python, c2 Python, c3 Fullstack, c4 Java | — | c5 Graphic Designer |
| UI/UX Designer | c1 UI/UX, c2 Product, c3 Visual | c4 Frontend (Figma-only) | c5 Backend Dev |
| Data Analyst | c1 Data Analyst, c2 Data Analyst, c3 Data Scientist | c4 Finance (Excel-only) | c5 HR Recruiter |
| HR Recruiter | c1 Tech Recruiter, c2 Recruitment Spec, c3 HR Generalist | — | c4 Admin, c5 Flutter Dev |

Cross-domain negatives verified `UNRELATED` / `NOT_MET` with `overall_score =
0.0`, `meets_job_description = false`, bottom of the ranking.

## How to run

### Direct pipeline check (deterministic, no API key)

```bash
cd backend
PYTHONPATH=. .venv/bin/python ../test_data/verify_dataset.py
```

Prints each job's parsed requirements and per-candidate
classification/score/meets-JD/relevance, plus a duplicate-name check (25 unique
names). With an API key the LLM also re-scores relevant candidates, so exact
scores vary — run with `Settings(llm_api_key=None)` for reproducibility.

### Through the API

For a single job:

```bash
# 1. Create the job from the JD file
curl -X POST http://localhost:8000/api/jobs \
  -F "title=Junior Flutter Developer" \
  -F "jd_file=@test_data/flutter_developer/job_description.txt"

# 2. Import the CVs
curl -X POST http://localhost:8000/api/jobs/<job_id>/candidates/import \
  -F "files=@test_data/flutter_developer/cvs/candidate_01_flutter_developer.pdf" \
  -F "files=@test_data/flutter_developer/cvs/candidate_02_flutter_developer_junior.pdf" \
  # ... repeat for candidates 03–05

# 3. Rank, then read persisted rankings
curl -X POST http://localhost:8000/api/jobs/<job_id>/rank
curl http://localhost:8000/api/jobs/<job_id>/rankings
```

## What the dataset surfaces

- **Same-domain permissiveness.** Any candidate sharing the job's professional
  domain or matching 2+ required skills is `RELEVANT`/`MET` (Android dev for a
  Flutter role, fullstack/Java for a Python backend role, Data Scientist for a
  Data Analyst role). Only cross-domain candidates with a single skill overlap
  get `PARTIALLY_MET`; Backend and HR jobs produce none.
- **Soft-skill-only JDs.** The HR Recruiter JD's required skills are all
  open-vocabulary or the excluded soft skill `communication`, so every CV there
  has `n_specific = 0`; classification is purely domain-driven.
- **JD wording shapes the job's detected domains.** The job's domains come from
  its title, required skills *and responsibilities*. "backend"/"QA" wording in a
  Flutter JD made an adjacent Java developer `RELEVANT`; the bundled Flutter JD
  deliberately avoids that wording so the cross-domain candidate lands
  `PARTIALLY_MET`.

Details per job: see each `README.md`. See also
[`docs/setup-and-testing.md`](../docs/setup-and-testing.md) §6 and ranking doc
[`docs/11-candidate-ranking.md`](../docs/11-candidate-ranking.md) §1.1.
