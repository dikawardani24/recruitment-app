# Flutter Developer — Sample Dataset

Sample dataset for exercising the recruitment application's **JD processing → CV
extraction → relevance detection → ranking** flow for a **Junior Flutter
Developer** role. All people, companies, and contacts are fictional.

```
flutter_developer/
├── job_description.txt
├── README.md
└── cvs/
    ├── candidate_01_flutter_developer.pdf
    ├── candidate_02_flutter_developer_junior.pdf
    ├── candidate_03_android_developer.pdf
    ├── candidate_04_java_developer.pdf
    └── candidate_05_accountant.pdf
```

## How to run it

Create a job with the JD file (`POST /api/jobs`, `jd_file=job_description.txt`),
import the five PDFs (`POST /api/jobs/{id}/candidates/import`), then rank
(`POST /api/jobs/{id}/rank`) and read results (`GET /api/jobs/{id}/rankings`).

Direct pipeline (deterministic, no API key):

```bash
cd backend
.venv/bin/python - <<'PY'
import asyncio
from pathlib import Path
from app.config import Settings
from app.extraction import extract_profile
from app.jd import RequirementParser
from app.parsers import extract_text
from app.ranking import RankingService

async def main():
    s = Settings(llm_api_key=None)
    base = Path("../test_data/flutter_developer")
    req = RequirementParser().parse(await extract_text("job.txt", (base / "job_description.txt").read_bytes()))
    cvs, profs = [], []
    for p in sorted((base / "cvs").glob("*.pdf")):
        t = await extract_text(p.name, p.read_bytes())
        profs.append(extract_profile(t, p.name))
        cvs.append({"id": p.stem, "file_name": p.name, "candidate_name": profs[-1].candidate_name})
    ranked, _ = await RankingService(s).rank(req, profs, cvs)
    for r in ranked:
        print(f"{r['file_name']:<42} {r['classification']:<13} score={r['overall_score']} meets_jd={r['meets_job_description']}")

asyncio.run(main())
PY
```

## Job description

Parsed requirements: `required_skills = [rest, flutter, dart, android, ios, git,
github, …]`, `min_years = 1`, `education = bsc`. The JD deliberately does not
mention "backend" or "QA" in its responsibilities so that adjacent developers
do not share those domains with the job.

## Candidates — intended vs verified

Exact numeric scores for the normal-ranking candidates are intentionally not
listed (they depend on scoring weights); only classification/relevance and the
verified ranking order.

| # | Candidate (fictional) | Profile | Intended | Verified | Meets JD | Relevance |
|---|-----------------------|---------|----------|----------|----------|-----------|
| 01 | Fathan Azka Ramadhan | Flutter Dev, 3+ yrs — Flutter/Dart/REST/Git/Firebase/state mgmt | `MET` | `MET` | yes | `RELEVANT` |
| 02 | Rizky Pratama | Flutter Dev, 2 yrs — Flutter/Dart/REST/Git/Firebase | `MET` | `MET` | yes | `RELEVANT` |
| 03 | Dimas Aditya Wijaya | Android Dev, 3+ yrs — Kotlin/Android SDK/REST/Git, learning Flutter | `PARTIALLY_MET` | `MET` | yes | `RELEVANT` |
| 04 | Andre Kusuma | Java Dev, 4 yrs — Java/Spring Boot/MySQL/REST | `PARTIALLY_MET`/`NOT_MET` | `PARTIALLY_MET` | no | `PARTIALLY_RELEVANT` |
| 05 | Siti Rahmawati | Senior Accountant, 8+ yrs — accounting/tax/audit/Excel | `NOT_MET` | `NOT_MET` | **no** | `UNRELATED` |

Verified ranking order: `01 > 02 > 03 > 04 > 05`, with 05 pinned to the bottom
at `score = 0`.

## Why each candidate gets its classification

- **01 (strong Flutter)** — matches most required skills (Flutter, Dart, REST,
  Git, GitHub, Android, iOS) plus preferred skills (Firebase, CI/CD). `MET`, top.
- **02 (good Flutter)** — a solid Flutter/Dart profile but fewer skills and
  slightly less experience than 01. `MET`, ranked second.
- **03 (Android)** — related **mobile** experience. The gate classifies it
  `RELEVANT`/`MET` because it matches required skills (Android, REST, Git,
  GitHub) and shares the `mobile` domain. It still ranks below 01/02 because
  Flutter/Dart/state-management depth is missing.
- **04 (Java)** — adjacent technical background with no Flutter/Dart/mobile
  experience; matches only the generic required skill `rest` and does not share
  the job's mobile domain, so the gate returns `PARTIALLY_RELEVANT`.
- **05 (Accountant)** — intentionally **unrelated** (finance domain, zero
  required-skill matches). Must be `NOT_MET` with `score = 0` and bottom of the
  ranking, despite 8+ years of experience.

## Intentionally unrelated candidate (negative test)

`candidate_05_accountant.pdf`:

```
Accountant CV + Flutter JD → UNRELATED → NOT_MET → score = 0 → bottom
```

It never receives a normal score: all sub-scores are forced to `0`, it is not
passed to LLM scoring, and the sort key places it below every relevant candidate.

## Cross-job behavior

The same Flutter CV behaves differently per job, as expected:

| CV | Job | Verified |
|----|-----|----------|
| candidate_01_flutter_developer.pdf | Flutter JD | `MET` |
| candidate_01_flutter_developer.pdf | Backend JD | `MET` (matches generic `git`/`rest`/`github`) |
| candidate_01_flutter_developer.pdf | HR Recruiter JD | `NOT_MET` |

## Observed behavior / known divergences

- **Same-domain "related" candidates are `MET`, not `PARTIALLY_MET`.** The gate
  (`app/ranking/_relevance.py`) returns `RELEVANT` when a candidate shares the
  job's professional domain or matches 2+ required skills. An Android developer
  (03) is therefore `MET`, not `PARTIALLY_MET`. Only genuinely cross-domain
  candidates (04) get `PARTIALLY_MET`. This is a property of the current gate —
  it is not "wrong", but it means the intended 03=PARTIALLY_MET outcome does not
  occur.
- **Open-vocabulary JD terms** (`riverpod`, `information technology`) appear in
  `required_skills`; they are unmatchable by CVs (dictionary-based extraction)
  but show up in `skill_gaps`.
- **Reproducibility:** verified with `Settings(llm_api_key=None)` (rules-based).
  With an API key, the LLM also re-scores relevant candidates, so exact scores
  vary.