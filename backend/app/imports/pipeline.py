from __future__ import annotations

from pathlib import Path

from app.config import Settings
from app.extraction import Profile, extract_profile_text
from app.parsers import extract_text


class CvProcessingError(Exception):
    """Raised when a single CV cannot be processed. The worker marks the
    document as failed and keeps going with the remaining files."""


async def extract_and_profile(
    settings: Settings, file_path: str, file_name: str
) -> tuple[Profile, str]:
    """Full per-CV pipeline: read stored file -> extract text -> extract a
    structured profile. Any failure raises and the document is marked failed
    without affecting the other CVs in the import."""
    try:
        content = Path(file_path).read_bytes()
        text = await extract_text(file_name, content)
        profile, source = await extract_profile_text(settings, text, file_name)
        return profile, source
    except CvProcessingError:
        raise
    except Exception as exc:  # unsupported file, unreadable pdf, etc.
        raise CvProcessingError(f"{type(exc).__name__}: {exc}") from exc
