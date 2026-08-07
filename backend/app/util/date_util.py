from __future__ import annotations

from datetime import datetime, timezone
from app.util.str_util import is_empty_string

def now() -> datetime:
    return datetime.now(timezone.utc)

def format_date(datetime: datetime) -> str:
    return datetime.isoformat()

def parse_date(date_str: str) -> datetime | None:
    if is_empty_string(date_str):
        return None
    return datetime.fromisoformat(date_str)