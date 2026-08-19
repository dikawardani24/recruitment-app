# HR Recruiter — Sample Dataset

Sample dataset for exercising **JD processing → CV extraction → relevance
detection → ranking** for an **HR Recruiter** role. All people, companies, and
contacts are fictional.

```
hr_recruiter/
├── job_description.txt
├── README.md
└── cvs/
    ├── candidate_01_technical_recruiter.pdf
    ├── candidate_02_recruitment_specialist.pdf
    ├── candidate_03_hr_generalist.pdf
    ├── candidate_04_administrative_coordinator.pdf
    └── candidate_05_flutter_developer.pdf
```

## How to run it

Create a job with the JD file (`POST /api/jobs`, `jd_file=job_description.txt`),
import the five PDFs (`POST /api/jobs/{id}/candidates/import`), then rank
(`POST /api/jobs/{id}/rank`). Or run the pipeline directly as in
`../flutter_developer/README.md` (swap the folder path).

## Job description

Parsed requirements: `required_skills = [communication, psychology, business,
recruitment, candidate screening, interviewing, talent acquisition, applicant
tracking systems, hr administration]`, `min_years = 3`, `education = bsc`.

Note: of these, only `communication` is a dictionary skill — and it is a **soft
skill**, which the relevance gate explicitly ignores. So for this job every CV
has `n_specific = 0`; classification depends entirely on whether the candidate
shares the job's detected `hr` professional domain.

## Candidates — intended vs verified

Exact numeric scores for normal-ranking candidates are intentionally not
listed; only classification/relevance and the verified ranking order.

| # | Candidate (fictional) | Profile | Intended | Verified | Meets JD | Relevance |
|---|-----------------------|---------|----------|----------|----------|-----------|
| 01 | Bagas Aditama | Technical Recruiter, 5 yrs — talent acquisition, screening, interviewing, ATS | `MET` | `MET` | yes | `RELEVANT` |
| 02 | Melati Puspita | Recruitment Specialist, 1.5 yrs — sourcing, screening, interviewing, ATS | `MET`/`PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 03 | Ratna Sari | HR Generalist, 4 yrs — HR operations, payroll, admin, recruiting | `PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 04 | Hendra Gunawan | Administrative Coordinator, 4 yrs — office admin, scheduling, documents | `PARTIALLY_MET`/`NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |
| 05 | Yoga Pratama | Flutter Developer, 3 yrs — Flutter/Dart/REST/Git | `NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |

Verified ranking order: `03 > 01 > 02 > 04`, with 04 and 05 pinned to the bottom
at `score = 0`. (05 is always last; 04 sorts above 05 but both are `NOT_MET`
with zeroed scores.)

## Why each candidate gets its classification

- **01 (Technical Recruiter)** — shares the `hr` domain (talent acquisition,
  screening, interviewing, ATS). `MET`, ranked second.
- **02 (Recruitment Specialist)** — shares the `hr` domain, but only 1.5 years
  (below the 3-year minimum) and fewer matched phrases, so it scores lowest
  among the relevant candidates.
- **03 (HR Generalist)** — shares the `hr` domain. Because the gate has no
  required-skill signal here, a generalist with less recruiting depth clears the
  same `RELEVANT` bar and happens to outrank 01 and 02 on score (more years +
  wider experience).
- **04 (Administrative Coordinator)** — the CV avoids every HR-domain keyword
  ("recruitment", "screening", "interviewing", "talent", "ATS", "HR"), so the
  candidate does not share the `hr` domain and has no required-skill matches.
  The gate returns `UNRELATED`/`NOT_MET`. This is the job's unintended negative:
  the profile was intended as `PARTIALLY_MET` but the strict gate produces
  `NOT_MET`.
- **05 (Flutter Developer)** — intentionally **unrelated** (software domain).
  Must be `NOT_MET` with `score = 0` and bottom of the ranking.

## Intentionally unrelated candidates (negative tests)

`candidate_04_administrative_coordinator.pdf` and
`candidate_05_flutter_developer.pdf`:

```
Admin CV + HR JD   → UNRELATED → NOT_MET → score = 0 → bottom
Flutter CV + HR JD → UNRELATED → NOT_MET → score = 0 → bottom
```

Neither ever receives a normal score: sub-scores are forced to `0`, they are not
passed to LLM scoring, and the sort key places them below every relevant
candidate.

## Cross-job behavior

| CV | Job | Verified |
|----|-----|----------|
| candidate_01_flutter_developer.pdf (Flutter job) | HR Recruiter JD | `NOT_MET` |
| candidate_01_technical_recruiter.pdf | HR Recruiter JD | `MET` |
| candidate_01_technical_recruiter.pdf | Data Analyst JD | `NOT_MET` |

## Observed behavior / known divergences

- **Soft-skill-only JD → the gate cannot detect relevance by skills.** All
  required skills here are either open-vocabulary or the soft skill
  `communication` (excluded from `n_specific`), so every CV has `n_specific =
  0`. Classification is purely domain-driven, and an HR Generalist (03) is
  `MET` exactly like a dedicated recruiter.
- **Adjacent admin roles are `NOT_MET`, not `PARTIALLY_MET`.** The admin
  coordinator (04) has no dictionary HR skill and avoids HR-domain vocabulary,
  so it is `UNRELATED`. This job therefore has no `PARTIALLY_MET` candidate.
- **Ranking order can look odd for relevant candidates** (03 generalist beats 01
  recruiter) because the score rewards years and breadth, not recruiting depth.
- **Reproducibility:** verified with `Settings(llm_api_key=None)` (rules-based).
  With an API key, the LLM also re-scores relevant candidates, so exact scores
  vary.