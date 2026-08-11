from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository


class ToolError(Exception):
    """Raised when a tool is unknown, its arguments are invalid, or its target
    entity cannot be resolved."""


@dataclass(frozen=True)
class Tool:
    name: str
    description: str
    parameters: dict  # JSON Schema
    handler: Any  # async (ToolRegistry, **kwargs) -> dict


class ToolRegistry:
    """Extensible set of functions the copilot may call. Each tool is an
    OpenAI-style JSON Schema plus an async handler. Add new capabilities by
    registering more [Tool]s (docs/10 §7)."""

    def __init__(self, job_repo: JobRepository, cv_repo: CvRepository):
        self.job_repo = job_repo
        self.cv_repo = cv_repo
        self._tools: dict[str, Tool] = {}
        for tool in _default_tools():
            self.register(tool)

    def register(self, tool: Tool) -> None:
        self._tools[tool.name] = tool

    def specs(self) -> list[dict]:
        return [
            {
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters,
                },
            }
            for tool in self._tools.values()
        ]

    async def execute(self, name: str, arguments: str) -> dict:
        tool = self._tools.get(name)
        if tool is None:
            raise ToolError(f"unknown_tool:{name}")
        try:
            parsed = json.loads(arguments or "{}")
        except (TypeError, ValueError) as exc:
            raise ToolError("invalid_tool_arguments") from exc
        if not isinstance(parsed, dict):
            raise ToolError("invalid_tool_arguments")
        return await tool.handler(self, **parsed)


def _require(**kwargs) -> None:
    for field, value in kwargs.items():
        if not value:
            raise ToolError(f"{field}_required")


async def _handle_list_jobs(registry: ToolRegistry, **kwargs) -> dict:
    page = await registry.job_repo.get_job(1, 50)
    jobs = page.data
    if not jobs:
        return {"jobs": []}
    counts = await registry.cv_repo.count_by_job_ids([job.id for job in jobs])
    return {
        "jobs": [
            {
                "job_id": job.id,
                "title": job.title,
                "status": job.status,
                "created_at": job.created_at.isoformat() if job.created_at else None,
                "candidate_count": counts.get(job.id, 0),
            }
            for job in jobs
        ]
    }


async def _handle_get_job_detail(registry: ToolRegistry, **kwargs) -> dict:
    _require(job_id=kwargs.get("job_id"))
    job = await registry.job_repo.get_by_id(kwargs["job_id"])
    if job is None:
        return {"error": "job_not_found", "job_id": kwargs["job_id"]}
    return job.to_json()


async def _handle_list_candidates(registry: ToolRegistry, **kwargs) -> dict:
    _require(job_id=kwargs.get("job_id"))
    job_id = kwargs["job_id"]
    candidates = await registry.cv_repo.find_by_job(job_id)
    return {
        "job_id": job_id,
        "candidates": [
            {
                "cv_id": candidate.id,
                "name": candidate.candidate_name or candidate.file_name,
                "file_name": candidate.file_name,
                "status": candidate.status,
                "years_experience": candidate.years_experience,
                "skills": candidate.skills,
                "overall_score": candidate.overall_score,
                "bucket": candidate.bucket,
                "ranked_by": candidate.ranked_by,
            }
            for candidate in candidates
        ],
    }


async def _handle_get_candidate_detail(registry: ToolRegistry, **kwargs) -> dict:
    _require(job_id=kwargs.get("job_id"), cv_id=kwargs.get("cv_id"))
    job_id = kwargs["job_id"]
    cv_id = kwargs["cv_id"]
    candidate = await registry.cv_repo.find_by_id(job_id, cv_id)
    if candidate is None:
        return {"error": "candidate_not_found", "job_id": job_id, "cv_id": cv_id}
    return candidate.to_json()


async def _handle_get_rankings(registry: ToolRegistry, **kwargs) -> dict:
    _require(job_id=kwargs.get("job_id"))
    job_id = kwargs["job_id"]
    if await registry.job_repo.get_by_id(job_id) is None:
        return {"error": "job_not_found", "job_id": job_id}
    candidates = await registry.cv_repo.find_by_job(job_id)
    ranked = [cv for cv in candidates if cv.overall_score is not None]
    ranked.sort(key=lambda c: c.overall_score, reverse=True)
    for i, cv in enumerate(ranked):
        cv.rank = i + 1
    return {"job_id": job_id, "count": len(ranked), "results": [cv.to_json() for cv in ranked]}


def _default_tools() -> list[Tool]:
    return [
        Tool(
            name="list_jobs",
            description=(
                "List the jobs in this workspace (id, title, status, created date, "
                "candidate count). Use it to find a job_id before calling "
                "get_job_detail or list_candidates."
            ),
            parameters={
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
            handler=_handle_list_jobs,
        ),
        Tool(
            name="get_job_detail",
            description=(
                "Get the full record for one job: description, requirements "
                "(skills, education, years, responsibilities), status and dates."
            ),
            parameters={
                "type": "object",
                "properties": {
                    "job_id": {"type": "string", "description": "The job's id."}
                },
                "required": ["job_id"],
                "additionalProperties": False,
            },
            handler=_handle_get_job_detail,
        ),
        Tool(
            name="list_candidates",
            description=(
                "List the candidates (CVs) attached to a job: id, name, experience, "
                "skills, and ranking bucket/score when ranked."
            ),
            parameters={
                "type": "object",
                "properties": {
                    "job_id": {"type": "string", "description": "The job's id."}
                },
                "required": ["job_id"],
                "additionalProperties": False,
            },
            handler=_handle_list_candidates,
        ),
        Tool(
            name="get_candidate_detail",
            description=(
                "Get the full profile of one candidate: profile text, skills, "
                "education, certifications, experience and ranking detail."
            ),
            parameters={
                "type": "object",
                "properties": {
                    "job_id": {"type": "string", "description": "The job's id."},
                    "cv_id": {"type": "string", "description": "The candidate's id."},
                },
                "required": ["job_id", "cv_id"],
                "additionalProperties": False,
            },
            handler=_handle_get_candidate_detail,
        ),
        Tool(
            name="get_rankings",
            description=(
                "Get the ranked list of candidates for a job with overall scores, "
                "buckets, and recommendation text."
            ),
            parameters={
                "type": "object",
                "properties": {
                    "job_id": {"type": "string", "description": "The job's id."}
                },
                "required": ["job_id"],
                "additionalProperties": False,
            },
            handler=_handle_get_rankings,
        ),
    ]
