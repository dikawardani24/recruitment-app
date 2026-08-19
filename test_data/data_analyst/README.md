# Data Analyst — Sample Dataset

Sample dataset for exercising **JD processing → CV extraction → relevance
detection → ranking** for a **Data Analyst** role. All people, companies, and
contacts are fictional.

```
data_analyst/
├── job_description.txt
├── README.md
└── cvs/
    ├── candidate_01_data_analyst.pdf
    ├── candidate_02_data_analyst_junior.pdf
    ├── candidate_03_data_scientist.pdf
    ├── candidate_04_finance_analyst.pdf
    └── candidate_05_hr_recruiter.pdf
```

## How to run it

Create a job with the JD file (`POST /api/jobs`, `jd_file=job_description.txt`),
import the five PDFs (`POST /api/jobs/{id}/candidates/import`), then rank
(`POST /api/jobs/{id}/rank`). Or run the pipeline directly as in
`../flutter_developer/README.md` (swap the folder path).

## Job description

Parsed requirements: `required_skills = [python, sql, pandas, excel, power bi,
statistics, data visualization, data analysis]`, `min_years = 2`, `education =
bsc`.

## Candidates — intended vs verified

Exact numeric scores for normal-ranking candidates are intentionally not
listed; only classification/relevance and the verified ranking order.

| # | Candidate (fictional) | Profile | Intended | Verified | Meets JD | Relevance |
|---|-----------------------|---------|----------|----------|----------|-----------|
| 01 | Sarah Lestari | Data Analyst, 4 yrs — Python/Pandas/SQL/Excel/Power BI, dashboards, statistics | `MET` | `MET` | yes | `RELEVANT` |
| 02 | Andi Firmansyah | Data Analyst, 1.5 yrs — SQL/Excel/Power BI (no Python, no Pandas) | `MET`/`PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 03 | Rina Kusuma | Data Scientist, 3 yrs — Python/Pandas/SQL/statistics/machine learning | `PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 04 | Taufik Hidayat | Finance Analyst, 5 yrs — Excel + financial modelling only (no SQL/Python/BI) | `PARTIALLY_MET`/`NOT_MET` | `PARTIALLY_MET` | no | `PARTIALLY_RELEVANT` |
| 05 | Cynthia Mutiara | HR Recruiter, 6 yrs — talent acquisition/screening (no data skills) | `NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |

Verified ranking order: `01 > 02 > 03 > 04 > 05`, with 05 pinned to the bottom
at `score = 0`.

## Why each candidate gets its classification

- **01 (strong)** — matches almost all required skills (Python, SQL, Pandas,
  Excel, Power BI, statistics, data visualization) plus preferred skills. `MET`,
  top.
- **02 (junior)** — matches SQL, Excel, Power BI (3 required skills) and shares
  the `data` domain, so it clears the gate as `MET`, but lacks Python/Pandas and
  is junior. Ranked second by score.
- **03 (Data Scientist)** — matches Python, SQL, Pandas, statistics and shares
  the `data` domain, so the gate returns `RELEVANT`/`MET` even though the
  profile is ML/modeling focused rather than analyst/reporting focused.
- **04 (Finance Analyst)** — matches only `excel` (one required skill) and does
  not share the job's `data` domain, so the gate returns `PARTIALLY_RELEVANT`.
  This is the dataset's cross-domain `PARTIALLY_MET` example for this job.
- **05 (HR Recruiter)** — intentionally **unrelated** (HR domain; the CV
  deliberately avoids "Excel", "data", "analysis", "reporting"). Must be
  `NOT_MET` with `score = 0` and bottom of the ranking.

## Intentionally unrelated candidate (negative test)

`candidate_05_hr_recruiter.pdf`:

```
HR CV + Data Analyst JD → UNRELATED → NOT_MET → score = 0 → bottom
```

It never receives a normal score: all sub-scores are forced to `0`, it is not
passed to LLM scoring, and the sort key places it below every relevant candidate.

## Cross-job behavior

| CV | Job | Verified |
|----|-----|----------|
| candidate_01_technical_recruiter.pdf (HR job) | Data Analyst JD | `NOT_MET` |
| candidate_01_data_analyst.pdf | Backend Developer JD | `MET` (matches `python`/`sql` → 2+ required) |
| candidate_01_ui_ux_designer.pdf (UI/UX job) | Data Analyst JD | `NOT_MET` |

## Observed behavior / known divergences

- **Data-adjacent profiles are `MET`, not `PARTIALLY_MET`.** The gate
  (`app/ranking/_relevance.py`) returns `RELEVANT` for any candidate sharing the
  `data` domain or matching 2+ required skills. A Data Scientist (03) is
  therefore `MET`. Only non-data profiles that match a single required skill
  (04, Excel-only) get `PARTIALLY_MET`.
- **2 required skills are enough to clear the gate.** 02 is `MET` on SQL +
  Excel + Power BI without Python/Pandas, and 03 on Python + SQL + Pandas
  without any analyst/reporting experience.
- **Reproducibility:** verified with `Settings(llm_api_key=None)` (rules-based).
  With an API key, the LLM also re-scores relevant candidates, so exact scores
  vary.