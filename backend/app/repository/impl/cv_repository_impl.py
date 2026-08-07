from app.domain.candidate import Candidate
from app.database.datasource.cv_datasource import CvDatasource


class CvRepositoryImpl:
    def __init__(self, datasource: CvDatasource):
        self.datasource = datasource

    async def save(self, candidate: Candidate):
        await self.datasource.save(candidate.to_entity())

    async def find_by_job(self, job_id: str) -> list[Candidate]:
        entities = await self.datasource.find_by_job(job_id)
        return [Candidate.from_entity(row) for row in entities]

    async def find_by_id(self, job_id: str, cv_id: str) -> Candidate | None:
        entity = await self.datasource.find_by_id(job_id, cv_id)
        if entity:
            return Candidate.from_entity(entity)
        return None

    async def delete(self, job_id: str, cv_id: str):
        await self.datasource.delete(job_id, cv_id)

    async def delete_by_job(self, job_id: str):
        await self.datasource.delete_by_job(job_id)

    async def count_by_job_ids(self, job_ids: list[str]) -> dict[str, int]:
        return await self.datasource.count_by_job_ids(job_ids)

    async def update_ranked(self, candidate: Candidate):
        await self.datasource.update_ranked(
            candidate.id,
            overall_score=candidate.overall_score,
            bucket=candidate.bucket,
            recommendation=candidate.recommendation,
            explanation=candidate.explanation,
            strengths=_dumps(candidate.strengths),
            weaknesses=_dumps(candidate.weaknesses),
            skill_gaps=_dumps(candidate.skill_gaps),
            skill_score=candidate.skill_score,
            experience_score=candidate.experience_score,
            education_score=candidate.education_score,
            certification_score=candidate.certification_score,
            ranked_at=candidate.ranked_at,
            ranked_by=candidate.ranked_by,
        )


def _dumps(value):
    import json

    return json.dumps(value) if value is not None else None
