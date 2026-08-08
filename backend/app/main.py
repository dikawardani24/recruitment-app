from __future__ import annotations

import asyncio
import contextlib
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database.db_client import DbClient
from app.di.injection import cv_processor
from app.routers import jobs

logger = logging.getLogger("ai_ats.access")


def _configure_logging() -> None:
    root = logging.getLogger("ai_ats")
    if root.handlers:
        return
    handler = logging.StreamHandler()
    handler.setFormatter(
        logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
    )
    root.setLevel(logging.INFO)
    root.addHandler(handler)


_configure_logging()


class RequestLogMiddleware:
    """Logs every HTTP request and its response status + duration."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        method = scope["method"]
        path = scope["path"]
        query = scope.get("query_string", b"").decode()
        target = f"{path}?{query}" if query else path

        logger.info("→ %s %s", method, target)
        status = {"code": 500}

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                status["code"] = message["status"]
                elapsed_ms = (time.perf_counter() - start) * 1000
                logger.info(
                    "← %s %s -> %s (%.1f ms)",
                    method,
                    target,
                    message["status"],
                    elapsed_ms,
                )
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception:
            elapsed_ms = (time.perf_counter() - start) * 1000
            logger.error(
                "✗ %s %s failed after %.1f ms",
                method,
                target,
                elapsed_ms,
                exc_info=True,
            )
            raise


@asynccontextmanager
async def lifespan(app: FastAPI):
    await DbClient().init_scheme()
    processor = cv_processor()
    await processor.reset_stale_processing()
    stop = asyncio.Event()
    worker_task = asyncio.create_task(processor.run(stop=stop))
    try:
        yield
    finally:
        stop.set()
        # Give the worker a moment to finish its current round gracefully.
        with contextlib.suppress(asyncio.TimeoutError):
            await asyncio.wait_for(asyncio.shield(worker_task), timeout=3)
        if not worker_task.done():
            worker_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await worker_task


app = FastAPI(title=settings.app_name, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestLogMiddleware)

API_PREFIX = "/api"
app.include_router(jobs.router, prefix=API_PREFIX)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "app": settings.app_name}
