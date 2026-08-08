from __future__ import annotations

import asyncio
import contextlib
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import db
from app.config import settings
from app.di.injection import cv_processor
from app.routers import jobs


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.init_db()
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

API_PREFIX = "/api"
app.include_router(jobs.router, prefix=API_PREFIX)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "app": settings.app_name}
