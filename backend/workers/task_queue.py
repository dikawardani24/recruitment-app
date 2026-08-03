from __future__ import annotations

from arq import cron

from app.core.container import Container


async def process_resume(ctx: dict, resume_id: str) -> str:
    container = ctx["container"]
    await container.process_resume_use_case().execute(resume_id)
    return f"processed {resume_id}"


class WorkerSettings:
    on_startup = lambda ctx: ctx.update(container=Container())  # noqa: E731
    functions = [process_resume]
    cron_jobs = [
        cron(
            # nightly re-index safety sweep (embedding version bumps)
            lambda ctx: None,
            cron="0 2 * * *",
        )
    ]
