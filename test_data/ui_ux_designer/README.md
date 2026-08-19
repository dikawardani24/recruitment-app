# UI/UX Designer — Sample Dataset

Sample dataset for exercising **JD processing → CV extraction → relevance
detection → ranking** for a **UI/UX Designer** role. All people, companies, and
contacts are fictional.

```
ui_ux_designer/
├── job_description.txt
├── README.md
└── cvs/
    ├── candidate_01_ui_ux_designer.pdf
    ├── candidate_02_product_designer.pdf
    ├── candidate_03_visual_designer.pdf
    ├── candidate_04_frontend_developer.pdf
    └── candidate_05_backend_developer.pdf
```

## How to run it

Create a job with the JD file (`POST /api/jobs`, `jd_file=job_description.txt`),
import the five PDFs (`POST /api/jobs/{id}/candidates/import`), then rank
(`POST /api/jobs/{id}/rank`). Or run the pipeline directly as in
`../flutter_developer/README.md` (swap the folder path).

## Job description

Parsed requirements: `required_skills = [figma, prototyping, wireframing,
human-computer interaction, user interface design, user flows, usability
testing]`, `min_years = 2`, `education = bsc`. The JD is deliberately written so
the bare tokens `ui` and `ux` never appear on their own (otherwise they would be
extracted as required skills and over-trigger relevance); it uses the compound
terms `user interface design` / `user experience` instead.

## Candidates — intended vs verified

Exact numeric scores for normal-ranking candidates are intentionally not
listed; only classification/relevance and the verified ranking order.

| # | Candidate (fictional) | Profile | Intended | Verified | Meets JD | Relevance |
|---|-----------------------|---------|----------|----------|----------|-----------|
| 01 | Maya Anggita | UI/UX Designer, 4 yrs — Figma, prototyping, wireframing, user flows, usability testing, design systems | `MET` | `MET` | yes | `RELEVANT` |
| 02 | Kevin Hartono | Product Designer, 3 yrs — Figma, user research, prototyping, usability testing | `MET` | `MET` | yes | `RELEVANT` |
| 03 | Lisa Wijayanti | Visual Designer, 4 yrs — Figma, prototyping, branding (no user research/testing) | `PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 04 | Rendra Saputra | Frontend Developer, 3 yrs — React/TypeScript/HTML/CSS, uses Figma only for handoff | `PARTIALLY_MET` | `PARTIALLY_MET` | no | `PARTIALLY_RELEVANT` |
| 05 | Daniel Hutapea | Backend Developer, 4 yrs — Python/FastAPI/PostgreSQL/Docker | `NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |

Verified ranking order: `01 ≈ 02 > 03 > 04 > 05`, with 05 pinned to the bottom
at `score = 0`. 01 and 02 tie on overall score (same matched-skill set and
experience band); their relative order can vary.

## Why each candidate gets its classification

- **01 (UI/UX Designer)** — matches most required skills (Figma, prototyping,
  wireframing, user flows, usability testing, user interface design). `MET`, top.
- **02 (Product Designer)** — matches Figma, prototyping, usability testing and
  user research; comparable to 01.
- **03 (Visual Designer)** — shares the `design` domain and matches Figma +
  prototyping (2+ required skills), so the gate returns `RELEVANT`/`MET` even
  though the profile is branding-focused with no UX research/testing.
- **04 (Frontend Developer)** — matches only `figma` (one required skill) and
  does not share the job's `design` domain, so the gate returns
  `PARTIALLY_RELEVANT`. This is the dataset's cross-domain `PARTIALLY_MET`
  example for this job.
- **05 (Backend Developer)** — intentionally **unrelated** (backend domain, zero
  required-skill matches; deliberately avoids the words "design", "UI", "UX",
  "wireframe", "prototype"). Must be `NOT_MET` with `score = 0` and bottom of
  the ranking.

## Intentionally unrelated candidate (negative test)

`candidate_05_backend_developer.pdf`:

```
Backend CV + UI/UX JD → UNRELATED → NOT_MET → score = 0 → bottom
```

It never receives a normal score: all sub-scores are forced to `0`, it is not
passed to LLM scoring, and the sort key places it below every relevant candidate.

## Cross-job behavior

| CV | Job | Verified |
|----|-----|----------|
| candidate_01_ui_ux_designer.pdf | UI/UX JD | `MET` |
| candidate_01_ui_ux_designer.pdf | Data Analyst JD | `NOT_MET` |

## Observed behavior / known divergences

- **Visual/graphic designers are `MET`, not `PARTIALLY_MET`.** The gate
  (`app/ranking/_relevance.py`) returns `RELEVANT` for any candidate sharing the
  `design` domain or matching 2+ required skills. A branding-focused designer
  (03) therefore clears the bar. Only non-designers who match a required skill
  (04, Figma-only) get `PARTIALLY_MET`.
- **01 and 02 tie** on score; tie-break is not specified, so their relative
  order is unstable.
- **Reproducibility:** verified with `Settings(llm_api_key=None)` (rules-based).
  With an API key, the LLM also re-scores relevant candidates, so exact scores
  vary.