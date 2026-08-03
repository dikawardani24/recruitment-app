from __future__ import annotations

from pathlib import Path

from app.core.config import StorageSettings
from app.core.ports import ObjectStorage


class LocalStorage(ObjectStorage):
    """Local filesystem implementation of ObjectStorage (dev default)."""

    def __init__(self, settings: StorageSettings) -> None:
        self._root = settings.local_root
        self._root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        safe = key.replace("/", "__")
        return self._root / safe

    async def put(self, key: str, data: bytes, content_type: str) -> None:
        self._path(key).write_bytes(data)

    async def get(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    async def delete(self, key: str) -> None:
        p = self._path(key)
        if p.exists():
            p.unlink()
