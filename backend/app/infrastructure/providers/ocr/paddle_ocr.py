from __future__ import annotations

import asyncio

from app.core.config import OCRSettings
from app.core.ports import OCRProvider


class PaddleOCRProvider(OCRProvider):
    """PaddleOCR adapter — layout/table-aware OCR for structured resumes."""

    def __init__(self, settings: OCRSettings) -> None:
        self._settings = settings
        self._ocr = None

    async def extract(self, image_bytes: bytes, lang: str = "eng") -> str:
        if self._ocr is None:
            from paddleocr import PaddleOCR  # heavy import — lazy

            self._ocr = PaddleOCR(use_angle_cls=True, lang=self._settings.lang)
        result = await asyncio.to_thread(self._ocr.ocr, image_bytes)
        lines: list[str] = []
        for page in result or []:
            for line in page or []:
                lines.append(line[1][0])
        return "\n".join(lines)
