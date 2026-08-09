from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime

from app.database.entities.job_entity import JobEntity
from app.util.str_util import is_empty_string
from app.util.date_util import format_date, parse_date


def _loads(value):
    if value is None:
        return None
    try:
        return json.loads(value)
    except (TypeError, ValueError):
        return None


@dataclass
class Job:
    def __init__(
        self,
        title: str,
        desc: str,
        req: str,
        status: str,
        created_at: datetime,
        updated_at: datetime,
        id: str,
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

    def is_data_valid(self):
        return not (
            is_empty_string(self.title)
            or is_empty_string(self.status)
        )

    def requirements(self) -> dict | None:
        return _loads(self.req)

    @classmethod
    def from_entity(cls, entity: JobEntity) -> Job:
        return cls(
            id= entity.id,
            title= entity.title,
            desc=entity.desc,
            req=entity.req,
            status=entity.status,
            created_at=parse_date(entity.created_at),
            updated_at=parse_date(entity.updated_at),
            jd_file_path=entity.jd_file_path
        )

    def to_entity(self) -> JobEntity :
        return JobEntity(
            id= self.id,
            title=self.title,
            desc=self.desc,
            req=self.req,
            status=self.status,
            created_at=format_date(self.created_at),
            updated_at=format_date(self.updated_at),
            jd_file_path=self.jd_file_path
        )

    def to_json(self):
        payload = {
            "job_id": self.id,
            "title": self.title,
            "description": self.desc,
            "status": self.status,
            "created_at": format_date(self.created_at),
            "updated_at": format_date(self.updated_at),
        }
        requirements = _loads(self.req)
        if requirements is not None:
            payload["requirements"] = requirements
        if self.jd_file_path:
            payload["jd_file"] = self.jd_file_path
        return payload