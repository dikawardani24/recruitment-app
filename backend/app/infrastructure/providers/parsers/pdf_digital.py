from __future__ import annotations

from app.core.ports import FileParser


class PdfPlumberParser(FileParser):
    """Digital PDF text extraction. Returns (text, meta) where meta flags density."""

    async def extract_text(self, data: bytes) -> tuple[str, dict]:
        try:
            import pdfplumber
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("pdfplumber not installed") from exc

        pages: list[str] = []
        char_count = 0
        with pdfplumber.open(data) as pdf:
            for page in pdf.pages:
                text = page.extract_text() or ""
                pages.append(text)
                char_count += len(text)

        text = "\n".join(pages).strip()
        return text, {"pages": len(pages), "chars": char_count, "used_ocr": False}
