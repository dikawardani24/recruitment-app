from __future__ import annotations

import asyncio
import subprocess

from app.core.config import OCRSettings
from app.core.ports import OCRProvider


class TesseractOCRProvider(OCRProvider):
    """Tesseract OCR adapter (scanned PDF fallback)."""

    def __init__(self, settings: OCRSettings) -> None:
        self._settings = settings

    async def extract(self, image_bytes: bytes, lang: str = "eng") -> str:
        return await asyncio.to_thread(self._run, image_bytes, lang)

    def _run(self, image_bytes: bytes, lang: str) -> str:
        result = subprocess.run(  # noqa: S603
            ["tesseract", "stdin", "stdout", "-l", lang or self._settings.lang],
            input=image_bytes,
            capture_output=True,
        )
        return result.stdout.decode("utf-8", errors="replace")
