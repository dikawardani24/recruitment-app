from __future__ import annotations

"""Deterministic answer builder for the recruiter copilot.

Answers workspace questions (existence, counts, filtered lists, resolved job/rank
lookups) using ONLY the registered API tools — zero Gemini calls. This is the
"User -> deterministic router -> API tool -> API response -> deterministic
response" path (0 Gemini requests).

The sentence-generation here is intentionally plain: it states exactly what the
workspace data contains and never invents numbers or candidates.
"""

import json

from app.chat._router import QueryRoute


def _call(registry, name: str, **kwargs) -> dict:
    return registry.execute(name, json.dumps(kwargs or {}))


def _skill_hit(skills: list[str], keywords: tuple[str, ...]) -> tuple[str, ...]:
    if not keywords:
        return tuple(skills)[:4]
    matched: list[str] = []
    for skill in skills:
        low = (skill or "").lower()
        if any(kw in low for kw in keywords):
            matched.append(skill)
    return tuple(matched)


def _title_hit(title: str, keywords: tuple[str, ...]) -> bool:
    low = (title or "").lower()
    return any(kw in low for kw in keywords) if keywords else True


def _plural(n: int, word: str) -> str:
    return f"{n} {word}{'s' if n != 1 else ''}"


def _score_text(score) -> str:
    if not isinstance(score, (int, float)):
        return ""
    return f", {score * 100:.0f}%"


def _candidate_card(cand: dict, job_id: str | None) -> dict:
    """A compact candidate row the chat UI can render as a tappable tile."""
    return {
        "job_id": job_id,
        "cv_id": cand.get("cv_id"),
        "name": cand.get("name") or cand.get("candidate_name") or cand.get("file_name"),
        "file_name": cand.get("file_name"),
        "status": cand.get("status"),
        "overall_score": cand.get("overall_score"),
        "bucket": cand.get("bucket"),
        "ranked_by": cand.get("ranked_by"),
    }


def _candidate_cards(items: list[dict]) -> list[dict]:
    if not items:
        return []
    return [{"type": "candidate", "items": items}]


def _job_cards(jobs: list[dict]) -> list[dict]:
    if not jobs:
        return []
    return [
        {
            "type": "job",
            "items": [
                {
                    "job_id": job.get("job_id"),
                    "title": job.get("title"),
                    "status": job.get("status"),
                    "candidate_count": job.get("candidate_count"),
                    "created_at": job.get("created_at"),
                }
                for job in jobs
            ],
        }
    ]


def _passes_score(score_filter: tuple[str, float] | None, cand: dict) -> bool:
    if score_filter is None:
        return True
    score = cand.get("overall_score")
    if not isinstance(score, (int, float)):
        return False
    op, value = score_filter
    if op == ">=":
        return score >= value
    if op == ">":
        return score > value
    if op == "<=":
        return score <= value
    if op == "<":
        return score < value
    return True


async def _all_jobs(registry):
    return (await registry.execute("list_jobs", "{}")).get("jobs", [])


async def _resolve_job(
    registry, job_ref: str | None, keywords: tuple[str, ...]
) -> dict | None:
    """Resolve the job a question refers to: explicit id first, else best title
    match for the extracted keywords. Returns the `list_jobs` entry or None."""
    jobs = await _all_jobs(registry)
    if not jobs:
        return None
    if job_ref:
        job_ref = job_ref.lower()
        for job in jobs:
            if job.get("job_id", "").lower() == job_ref:
                return job
    if not keywords:
        return jobs[0] if len(jobs) == 1 else None
    best: dict | None = None
    best_hits = -1
    for job in jobs:
        title = (job.get("title") or "").lower()
        hits = sum(1 for kw in keywords if kw in title)
        if hits > best_hits:
            best_hits = hits
            best = job
    return best if best_hits > 0 else None


async def _candidates_for(registry, job: dict) -> list[dict]:
    payload = await _call(registry, "list_candidates", job_id=job["job_id"])
    return payload.get("candidates", [])


async def _resolve_job_by_person(
    registry, keywords: tuple[str, ...]
) -> dict | None:
    """Fallback for questions that name candidates ("why is John ranked higher
    than Sarah?"): find the job a named candidate is attached to."""
    for job in await _all_jobs(registry):
        for cand in await _candidates_for(registry, job):
            name = (cand.get("name") or "").lower()
            if any(kw in name for kw in keywords):
                return job
    return None


async def answer_statistics(registry) -> str:
    jobs = await _all_jobs(registry)
    total = sum(job.get("candidate_count", 0) for job in jobs)
    lines = [_plural(len(jobs), "job posting")]
    if total:
        lines.append(_plural(total, "applicant"))
    else:
        lines.append("no applicants yet")
    return "You have " + " and ".join(lines) + " in this workspace."


async def answer_candidate_search(
    registry,
    keywords: tuple[str, ...],
    score_filter: tuple[str, float] | None = None,
) -> tuple[str, list[dict], list[dict]]:
    jobs = await _all_jobs(registry)
    sources: list[dict] = []
    found: list[tuple[str, str, tuple[str, ...], float | None]] = []
    card_items: list[dict] = []
    for job in jobs:
        for cand in await _candidates_for(registry, job):
            if not _passes_score(score_filter, cand):
                continue
            matched = _skill_hit(cand.get("skills") or [], keywords)
            if not keywords or matched:
                found.append(
                    (
                        cand.get("name") or cand.get("cv_id") or "?",
                        job.get("title") or job.get("job_id") or "?",
                        matched,
                        cand.get("overall_score"),
                    )
                )
                card_items.append(_candidate_card(cand, job.get("job_id")))
                sources.append(
                    {
                        "entity_type": "candidate",
                        "entity_id": cand.get("cv_id"),
                        "entity_name": cand.get("name"),
                        "section": "skills",
                        "score": float(cand.get("overall_score") or 0.0),
                        "status": cand.get("status"),
                        "ranked_by": cand.get("ranked_by"),
                    }
                )
    cards = _candidate_cards(card_items)
    if not keywords:
        if not found:
            return "There are no applicants in this workspace yet.", [], []
        summary = _plural(len(found), "applicant")
        items = [
            f"{name} ({job}): {', '.join(skills) if skills else 'no skills listed'}"
            f"{_score_text(score)}"
            for name, job, skills, score in found
        ]
        return f"There are {summary}:\n" + "\n".join(f"- {item}" for item in items), sources, cards

    if not found:
        term = " or ".join(keywords)
        note = f" with a score {score_filter[0]} {score_filter[1] * 100:.0f}%" if score_filter else ""
        return (
            f"There are no candidates matching {term!r}{note} in this workspace. "
            "You might need to create a job and add candidates first.",
            [],
            [],
        )
    if len(found) == 1:
        name, job, matched, score = found[0]
        skills = ", ".join(matched) if matched else "no matching skills listed"
        return (
            f"Yes. {name} for the {job} position lists: {skills}{_score_text(score)}.",
            sources,
            cards,
        )
    names = ", ".join(
        f"{name} ({job}{_score_text(score)})"
        f"{(' — ' + ', '.join(matched)) if matched else ''}"
        for name, job, matched, score in found
    )
    return f"Yes, {len(found)} applicants match: {names}.", sources, cards


async def answer_job_search(
    registry, keywords: tuple[str, ...]
) -> tuple[str, list[dict], list[dict]]:
    jobs = await _all_jobs(registry)
    matched: list[dict] = []
    for job in jobs:
        if _title_hit(job.get("title", ""), keywords):
            matched.append(job)
    if not matched:
        term = " or ".join(keywords) if keywords else ""
        return f"No job posting matches{(' ' + term) if term else ''}.", [], []
    lines = [
        f"- {job.get('title')} ({job.get('status')}, "
        f"{job.get('candidate_count', 0)} applicants)"
        for job in matched
    ]
    return "Found:\n" + "\n".join(lines), [
        {
            "entity_type": "job",
            "entity_id": job.get("job_id"),
            "entity_name": job.get("title"),
            "section": "metadata",
            "score": 1.0,
        }
        for job in matched
    ], _job_cards(matched)


async def answer_job_detail(
    registry, job_ref: str | None, keywords: tuple[str, ...]
) -> tuple[str, list[dict], list[dict]]:
    job = await _resolve_job(registry, job_ref, keywords)
    if job is None:
        term = " or ".join(keywords) if keywords else ""
        return (
            f"I couldn't find that job{(' (' + term + ')') if term else ''} "
            "in the workspace.",
            [],
            [],
        )
    detail = await _call(registry, "get_job_detail", job_id=job["job_id"])
    if "error" in detail:
        return f"I couldn't find that job ({detail['error']}).", [], []
    lines = [f"{detail.get('title')} — {detail.get('status')}"]
    if detail.get("description"):
        lines.append(detail["description"])
    requirements = detail.get("requirements")
    if isinstance(requirements, dict) and requirements:
        for key, value in requirements.items():
            if isinstance(value, list):
                if value:
                    lines.append(f"{key}: {', '.join(str(v) for v in value)}")
            elif value:
                lines.append(f"{key}: {value}")
    return "\n".join(lines), [
        {
            "entity_type": "job",
            "entity_id": job.get("job_id"),
            "entity_name": detail.get("title"),
            "section": "description",
            "score": 1.0,
        }
    ], []


async def answer_rankings(
    registry,
    job_ref: str | None,
    keywords: tuple[str, ...],
    score_filter: tuple[str, float] | None = None,
) -> tuple[str, list[dict], list[dict]]:
    job = await _resolve_job(registry, job_ref, keywords)
    if job is None:
        job = await _resolve_job_by_person(registry, keywords)
    if job is None:
        term = " or ".join(keywords) if keywords else ""
        return (
            f"I couldn't find that job{(' (' + term + ')') if term else ''} "
            "in the workspace.",
            [],
            None,
        )
    payload = await _call(registry, "get_rankings", job_id=job["job_id"])
    if "error" in payload:
        return (
            f"I couldn't load rankings for {job.get('title')} "
            f"({payload['error']}).",
            [],
            None,
        )
    results = payload.get("results", [])
    if score_filter:
        results = [
            r for r in results
            if _passes_score(score_filter, {"overall_score": r.get("overall_score")})
        ]
    if not results:
        note = (
            f" with a score {score_filter[0]} {score_filter[1] * 100:.0f}%"
            if score_filter
            else ""
        )
        return f"No ranked candidates{note} yet for {job.get('title')}.", [], []
    lines = [f"Rankings for {job.get('title')}:"]
    for rank in results:
        score = rank.get("overall_score")
        score_text = f" ({score:.2f})" if isinstance(score, (int, float)) else ""
        bucket = f", {rank.get('bucket')}" if rank.get("bucket") else ""
        lines.append(f"{rank.get('rank')}. {rank.get('candidate_name')}{score_text}{bucket}")
    return "\n".join(lines), [
        {
            "entity_type": "candidate",
            "entity_id": rank.get("cv_id"),
            "entity_name": rank.get("candidate_name"),
            "section": "ranking",
            "score": float(rank.get("overall_score") or 0.0),
            "status": rank.get("status"),
            "ranked_by": rank.get("ranked_by"),
        }
        for rank in results
    ], _candidate_cards(
        [_candidate_card(rank, job.get("job_id")) for rank in results]
    )


async def deterministic_answer(
    route: QueryRoute, registry
) -> tuple[str, list[dict], list[dict]]:
    """Runs the routed API tools and formats a plain-text answer. Zero Gemini.

    Returns ``(answer, sources, cards)`` where ``cards`` is a structured list
    payload (``{"type": "job" | "candidate", "items": [...]}``) the chat UI can
    render as tappable cards, or None when the answer has no list."""
    if route.intent == "application_statistics":
        return await answer_statistics(registry), [], []
    if route.intent == "candidate_search":
        return await answer_candidate_search(registry, route.keywords, route.score_filter)
    if route.intent == "job_search":
        return await answer_job_search(registry, route.keywords)
    if route.intent == "job_detail":
        return await answer_job_detail(registry, route.job_ref, route.keywords)
    if route.intent == "candidate_ranking":
        return await answer_rankings(registry, route.job_ref, route.keywords, route.score_filter)
    # Conservative fallback for an unexpected deterministic label.
    return "I couldn't determine a direct answer from the workspace data.", [], []


async def prefetch_records(
    route: QueryRoute, registry, requested_job_id: str | None
) -> dict:
    """Prefetch workspace records BEFORE the single Gemini reasoning call for
    intents that need job/candidate context. Never a multi-round tool loop."""
    records: dict = {"jobs": [], "candidates": [], "rankings": []}
    jobs = await _all_jobs(registry)
    if not jobs:
        return records

    def _candidate_view(cand: dict) -> dict:
        return {
            k: cand.get(k) for k in (
                "cv_id", "candidate_name", "years_experience", "skills",
                "education", "certifications", "overall_score", "bucket",
                "recommendation",
            ) if cand.get(k) is not None
        }

    if route.intent in ("candidate_search", "candidate_detail", "other"):
        # Give the reasoning pass the actual candidate profiles (skills, years)
        # so a follow-up like "what are their skills?" has real data.
        records["jobs"] = [
            {"job_id": j.get("job_id"), "title": j.get("title"), "status": j.get("status")}
            for j in jobs
        ]
        for job in jobs:
            for cand in await _candidates_for(registry, job):
                if not _passes_score(route.score_filter, cand):
                    continue
                records["candidates"].append(_candidate_view(cand))
                if len(records["candidates"]) >= 12:
                    return records
        return records

    if route.intent not in ("candidate_ranking", "candidate_comparison", "job_requirement_matching"):
        return records

    job: dict | None = None
    if requested_job_id:
        job = next((j for j in jobs if j.get("job_id") == requested_job_id), None)
    if job is None:
        job = await _resolve_job(registry, route.job_ref, route.keywords)
    if job is None:
        return records
    detail = await _call(registry, "get_job_detail", job_id=job["job_id"])
    if "error" not in detail:
        records["jobs"].append(detail)
    candidates = await _candidates_for(registry, job)
    records["candidates"] = [
        _candidate_view(c)
        for c in candidates
        if _passes_score(route.score_filter, c)
    ]
    try:
        rankings = await _call(registry, "get_rankings", job_id=job["job_id"])
        if "error" not in rankings:
            records["rankings"] = rankings.get("results", [])
    except Exception:
        pass
    return records
