from __future__ import annotations

"""Shared Gemini-call safeguards.

Gemini has a hard ~5 RPM / 250k TPM cap and has already produced
RateLimitErrors, so every LLM request goes through:

- ``bounded_retry``: exponential backoff on retryable (429/5xx) errors with a
  hard cap. Never retries indefinitely.
- ``rate_capped_wait``: a process-wide minimum interval between LLM calls so the
  interactive chat path stays comfortably under the RPM ceiling.

Retryability is detected by exception class name so this module does not import
any provider SDK (works with OpenAI-compatible and Gemini endpoints alike).
"""

import asyncio
import random
import time
from typing import Awaitable, Callable, TypeVar

T = TypeVar("T")

# Exception class names that are safe to retry (transient provider-side).
_RETRYABLE_NAMES = frozenset(
    {
        "RateLimitError",
        "InternalServerError",
        "APIConnectionError",
        "APITimeoutError",
        "ServiceUnavailableError",
        "GatewayTimeoutError",
        "ConflictError",
    }
)
# Transient HTTP statuses as a fallback (OpenAI/Gemini responses).
_RETRYABLE_STATUSES = frozenset({429, 500, 502, 503, 504, 529})


def _is_retryable(exc: Exception) -> bool:
    if type(exc).__name__ in _RETRYABLE_NAMES:
        return True
    status = getattr(getattr(exc, "response", None), "status_code", None)
    if status in _RETRYABLE_STATUSES:
        return True
    # OpenRouter returns HTTP 400 "Provider returned error" when an upstream
    # provider is temporarily unavailable; the JSON body carries provider
    # metadata (e.g. {"error": {"metadata": {"provider_name": ...}}}). Treat
    # that as transient too so a flaky upstream does not fail the whole turn.
    if status == 400 and _has_provider_metadata(exc):
        return True
    return False


def _has_provider_metadata(exc: Exception) -> bool:
    try:
        body = getattr(getattr(exc, "response", None), "json", None)
        if body is None:
            return False
        data = body()
        metadata = data.get("error", {}).get("metadata")
        return bool(metadata and isinstance(metadata, dict))
    except Exception:
        return False

_RATE_LOCK = asyncio.Lock()
_last_call_at = 0.0


async def rate_capped_wait(min_interval_s: float) -> None:
    """Serialise LLM calls and enforce a minimum gap between them."""
    if min_interval_s <= 0:
        return
    global _last_call_at
    async with _RATE_LOCK:
        now = time.monotonic()
        delay = _last_call_at + min_interval_s - now
        if delay > 0:
            await asyncio.sleep(delay)
        _last_call_at = time.monotonic()


def _retry_after_seconds(exc: Exception) -> float | None:
    response = getattr(exc, "response", None)
    if response is not None:
        try:
            headers = response.headers
        except Exception:
            headers = None
        if headers is not None:
            value = headers.get("retry-after")
            if value:
                try:
                    return max(0.0, float(value))
                except (TypeError, ValueError):
                    pass
    try:
        value = getattr(exc, "retry_after", None)
        if value is not None:
            return max(0.0, float(value))
    except (TypeError, ValueError):
        pass
    return None


async def bounded_retry(
    factory: Callable[[], Awaitable[T]],
    *,
    max_retries: int = 3,
    base_delay_s: float = 1.5,
    max_delay_s: float = 30.0,
) -> T:
    """Call ``factory()`` retrying only transient provider errors.

    Backoff doubles each attempt with jitter, honors ``retry-after`` when the
    provider sends it, and stops after ``max_retries`` attempts. Other errors
    propagate immediately (they are surfaced as typed chat/extract/rank errors).
    """
    attempt = 0
    delay = base_delay_s
    while True:
        try:
            return await factory()
        except Exception as exc:
            if attempt >= max_retries or not _is_retryable(exc):
                raise
            attempt += 1
            retry_after = _retry_after_seconds(exc)
            sleep = retry_after or min(delay * random.uniform(0.8, 1.3), max_delay_s)
            await asyncio.sleep(sleep)
            delay = min(delay * 2, max_delay_s)
