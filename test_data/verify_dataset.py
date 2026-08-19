#!/usr/bin/env python3
"""Run the full extraction + ranking pipeline over every job in test_data/.

Deterministic rules-based path (llm_api_key=None) so results are reproducible
without an API key. Prints per-job: JD summary, per-candidate classification
and ranking order, plus a duplicate-name check across all jobs.

Run from the repo root's backend virtualenv:

    cd backend
    PYTHONPATH=. .venv/bin/python ../test_data/verify_dataset.py

No files are created or modified (read-only verification of the sample data).
"""
from __future__ import annotations

import asyncio
from pathlib import Path

from app.config import Settings
from app.extraction import extract_profile
from app.jd import RequirementParser
from app.parsers import extract_text
from app.ranking import RankingService

BASE = Path(__file__).resolve().parent
JOBS = ["flutter_developer", "backend_developer", "ui_ux_designer", "data_analyst", "hr_recruiter"]


async def main() -> None:
    settings = Settings(llm_api_key=None)
    seen_names: set[str] = set()
    for folder in JOBS:
        jd_text = await extract_text("job.txt", (BASE / folder / "job_description.txt").read_bytes())
        req = RequirementParser().parse(jd_text)
        print(f"===== {folder} =====")
        print(f"  JD: title={req['title']} min_years={req['min_years']} edu={req['education']}")
        print(f"  required_skills: {req['required_skills']}")

        profiles, cvs = [], []
        for path in sorted((BASE / folder / "cvs").glob("*.pdf")):
            text = await extract_text(path.name, path.read_bytes())
            prof = extract_profile(text, path.name)
            profiles.append(prof)
            cvs.append({"id": path.stem, "file_name": path.name, "candidate_name": prof.candidate_name})
            if prof.candidate_name in seen_names:
                print(f"  !! DUPLICATE NAME: {prof.candidate_name}")
            seen_names.add(prof.candidate_name)

        ranked, source = await RankingService(settings).rank(req, profiles, cvs)
        print(f"  (source={source})")
        for r in ranked:
            print(
                f"    {r['file_name']:<42} {r['classification']:<13} score={r['overall_score']:<5} "
                f"bucket={r['bucket']:<14} meets_jd={str(r['meets_job_description']):<5} relevance={r['relevance']}"
            )
        print()

    print(f"TOTAL UNIQUE NAMES: {len(seen_names)}")


if __name__ == "__main__":
    asyncio.run(main())
