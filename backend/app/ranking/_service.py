from __future__ import annotations

from datetime import datetime, timezone

from app.config import Settings
from app.extraction import Profile
from app.ranking._llm import LLMRankingError, rank_with_llm
from app.ranking._scoring import bucket_for, rule_reasoning, score_profile


class RankingService:
    """Score + rank parsed CVs against a job, with LLM reasoning when configured."""

    def __init__(self, settings: Settings):
        self.settings = settings

    async def rank(self, requirements: dict, profiles: list[Profile], cvs: list[dict]) -> tuple[list[dict], str]:
        scores_by_cv = {
            cv["id"]: score_profile(profiles[i], requirements, self.settings)
            for i, cv in enumerate(cvs)
        }
        llm_rankings = await self._llm_rank(requirements, profiles)
        source = "llm" if llm_rankings is not None else "rules"

        ranked = []
        if llm_rankings and len(llm_rankings) == len(cvs):
            for i, cv in enumerate(cvs):
                llm = llm_rankings[i]
                scores = scores_by_cv[cv["id"]]
                ranked.append(
                    {
                        **cv,
                        "overall_score": llm.overall,
                        "bucket": bucket_for(llm.overall),
                        "recommendation": llm.recommendation,
                        "explanation": llm.explanation,
                        "strengths": llm.strengths,
                        "weaknesses": llm.weaknesses,
                        "skill_gaps": scores["missing_required"],
                        "skill_score": scores["skill_score"],
                        "experience_score": scores["experience_score"],
                        "education_score": scores["education_score"],
                        "certification_score": scores["certification_score"],
                        "ranked_at": _now(),
                    }
                )
        else:
            for i, cv in enumerate(cvs):
                scores = scores_by_cv[cv["id"]]
                reasoning = rule_reasoning(profiles[i], requirements, scores)
                ranked.append(
                    {
                        **cv,
                        "overall_score": scores["overall"],
                        "bucket": bucket_for(scores["overall"]),
                        "recommendation": reasoning["recommendation"],
                        "explanation": reasoning["explanation"],
                        "strengths": reasoning["strengths"],
                        "weaknesses": reasoning["weaknesses"],
                        "skill_gaps": reasoning["skill_gaps"],
                        "skill_score": scores["skill_score"],
                        "experience_score": scores["experience_score"],
                        "education_score": scores["education_score"],
                        "certification_score": scores["certification_score"],
                        "ranked_at": _now(),
                    }
                )
        ranked.sort(key=lambda c: c["overall_score"], reverse=True)
        return ranked, source

    async def _llm_rank(self, requirements: dict, profiles: list[Profile]):
        if not self.settings.llm_enabled:
            return None
        try:
            return await rank_with_llm(
                self.settings,
                _flatten_requirements(requirements),
                [p.as_dict() for p in profiles],
            )
        except LLMRankingError:
            return None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _flatten_requirements(req: dict) -> dict:
    return {
        "title": req.get("title"),
        "required_skills": req.get("required_skills"),
        "preferred_skills": req.get("preferred_skills"),
        "min_years": req.get("min_years"),
        "education": req.get("education"),
        "certifications": req.get("certifications"),
        "responsibilities": req.get("responsibilities"),
    }
