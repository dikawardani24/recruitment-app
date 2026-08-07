from __future__ import annotations

from pathlib import Path
from uuid import uuid4


def save_file(upload_dir: Path, suffix: str, content: bytes) -> str:
    upload_dir.mkdir(parents=True, exist_ok=True)
    path = upload_dir / f"{uuid4().hex}{suffix}"
    path.write_bytes(content)
    return str(path)


def delete_storage_file(path: str | None) -> None:
    if not path:
        return
    try:
        Path(path).unlink(missing_ok=True)
    except OSError:
        pass
