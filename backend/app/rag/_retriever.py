from __future__ import annotations

import asyncio
from dataclasses import dataclass

from app.rag._indexer import EmbeddingIndexer


@dataclass
class Evidence:
    entity_type: str
    entity_id: str
    job_id: str | None
    entity_name: str
    section: str
    content: str
    score: float

    def as_dict(self) -> dict:
        return {
            "entity_type": self.entity_type,
            "entity_id": self.entity_id,
            "job_id": self.job_id,
            "entity_name": self.entity_name,
            "section": self.section,
            "content": self.content,
            "score": self.score,
        }


async def retrieve_evidence(
    indexer: EmbeddingIndexer,
    query: str,
    job_id: str | None = None,
    top_k: int = 10,
    max_evidence: int = 8,
) -> list[Evidence]:
    """Cross-entity retrieval for the copilot: searches both the candidate and
    the job index, merges by descending score, and keeps per-entity section
    diversity so one candidate's many chunks don't drown out the rest
    (docs/10 §3.1)."""
    candidate_hits, job_hits = await asyncio.gather(
        indexer.search(query, "candidate", top_k=top_k, job_id=job_id),
        indexer.search(query, "job", top_k=top_k),
    )

    evidence = [_as_evidence(h, "candidate") for h in candidate_hits]
    evidence += [_as_evidence(h, "job") for h in job_hits]
    evidence.sort(key=lambda e: e.score, reverse=True)

    seen: set[tuple] = set()
    per_entity: dict[tuple, int] = {}
    out: list[Evidence] = []
    for item in evidence:
        key = (item.entity_type, item.entity_id, item.section)
        if key in seen:
            continue
        seen.add(key)
        entity_key = (item.entity_type, item.entity_id)
        if per_entity.get(entity_key, 0) >= 3:
            continue
        per_entity[entity_key] = per_entity.get(entity_key, 0) + 1
        out.append(item)
        if len(out) >= max_evidence:
            break
    return out


def _as_evidence(hit, entity_type: str) -> Evidence:
    payload = hit.payload
    return Evidence(
        entity_type=entity_type,
        entity_id=payload.get("entity_id"),
        job_id=payload.get("job_id"),
        entity_name=payload.get("entity_name") or "",
        section=payload.get("section") or "",
        content=payload.get("content") or "",
        score=hit.score,
    )
