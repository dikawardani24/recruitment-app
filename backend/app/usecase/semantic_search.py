from __future__ import annotations

from app.rag._indexer import EmbeddingIndexer
from app.repository.cv_repository import CvRepository
from app.repository.job_repository import JobRepository

MAX_RESULTS = 50
SNIPPET_CHARS = 300


class SemanticSearch:
    """Semantic search over jobs and candidates (docs/10 §3). Query is embedded
    with the BGE instruction prefix, vectors are searched in Qdrant filtered by
    entity type / job, hits are grouped per entity with section diversity, then
    hydrated from the repositories. Degrades to a "disabled" response when RAG
    is not configured."""

    def __init__(
        self,
        indexer: EmbeddingIndexer | None,
        job_repo: JobRepository,
        cv_repo: CvRepository,
    ):
        self.indexer = indexer
        self.job_repo = job_repo
        self.cv_repo = cv_repo

    def _disabled(self, query: str, entity: str) -> dict:
        return {
            "enabled": False,
            "entity": entity,
            "query": query,
            "count": 0,
            "results": [],
        }

    async def execute(
        self,
        query: str,
        entity: str,
        top_k: int = 10,
        job_id: str | None = None,
    ) -> dict:
        query = (query or "").strip()
        if self.indexer is None or not self.indexer.enabled:
            return self._disabled(query, entity)
        if entity not in ("job", "candidate"):
            raise ValueError("entity_must_be_job_or_candidate")
        if not query:
            return {"enabled": True, "entity": entity, "query": query, "count": 0, "results": []}

        top_k = max(1, min(top_k, MAX_RESULTS))
        hits = await self.indexer.search(
            query=query,
            entity_type=entity,
            top_k=top_k,
            job_id=job_id,
        )
        grouped = self._group(hits)
        return await self._hydrate(query, entity, grouped)

    def _group(self, hits: list) -> list[dict]:
        """Group chunk hits per entity; per entity keep top-scoring sections
        (section diversity, docs/10 §3.1) and a best-score equal to the max
        section score."""
        entities: dict[tuple[str, str], dict] = {}
        for hit in hits:
            payload = hit.payload
            key = (payload.get("entity_id"), payload.get("job_id"))
            entry = entities.setdefault(
                key,
                {
                    "entity_id": payload.get("entity_id"),
                    "job_id": payload.get("job_id"),
                    "name": payload.get("entity_name") or "",
                    "best_score": -1.0,
                    "sections": {},
                },
            )
            entry["best_score"] = max(entry["best_score"], hit.score)
            entry["sections"].setdefault(payload.get("section", ""), 0.0)
            entry["sections"][payload.get("section", "")] = max(
                entry["sections"][payload.get("section", "")], hit.score
            )

        results = []
        for entry in entities.values():
            sections = sorted(
                (
                    {"section": section, "score": score}
                    for section, score in entry["sections"].items()
                ),
                key=lambda s: s["score"],
                reverse=True,
            )
            results.append(
                {
                    "entity_id": entry["entity_id"],
                    "job_id": entry["job_id"],
                    "name": entry["name"],
                    "score": entry["best_score"],
                    "sections": sections[:3],
                }
            )
        results.sort(key=lambda r: r["score"], reverse=True)
        return results

    async def _hydrate(self, query: str, entity: str, grouped: list[dict]) -> dict:
        hydrated = []
        for row in grouped:
            if entity == "job":
                job = await self.job_repo.get_by_id(row["entity_id"])
                if job is None:
                    continue
                hydrated.append(
                    {
                        "entity_type": entity,
                        "id": job.id,
                        "name": job.title,
                        "score": row["score"],
                        "sections": row["sections"],
                        "job": job.to_json(),
                    }
                )
            else:
                candidate = await self.cv_repo.find_by_id(row["job_id"], row["entity_id"])
                if candidate is None:
                    continue
                hydrated.append(
                    {
                        "entity_type": entity,
                        "id": candidate.id,
                        "job_id": candidate.job_id,
                        "name": candidate.candidate_name,
                        "score": row["score"],
                        "sections": row["sections"],
                        "candidate": candidate.to_json(),
                    }
                )

        return {
            "enabled": True,
            "entity": entity,
            "query": query,
            "count": len(hydrated),
            "results": hydrated,
        }
