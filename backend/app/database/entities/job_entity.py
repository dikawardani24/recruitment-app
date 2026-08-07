from __future__ import annotations

from uuid import uuid4
from dataclasses import dataclass

import sqlite3

@dataclass
class JobEntity:
    def __init__(
        self,
        title: str,
        desc: str,
        req: str,
        status: str,
        created_at: str,
        updated_at: str,
        id: str = str(uuid4()),
        jd_file_path = None
    ):
        self.id = id
        self.title = title
        self.desc = desc
        self.req = req
        self.status = status
        self.created_at = created_at
        self.updated_at = updated_at
        self.jd_file_path = jd_file_path

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> JobEntity:
        return cls(
            id=row["id"],
            title=row["title"],
            desc=row["description"],
            req=row["requirements"],
            status=row["status"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            jd_file_path=row["jd_file"],
        )