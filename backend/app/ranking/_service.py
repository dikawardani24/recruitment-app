from __future__ import annotations

from datetime import datetime, timezone

from app.config import Settings
from app.extraction import Profile
from app.ranking._llm import LLMRankingError, rank_with_llm
from app.ranking._relevance import NOT_MET, evaluate_relevance
from app.ranking._scoring import bucket_for, rule_reasoning, score_profile

_NOT_MET_BUCKET = "not_met"
_NOT_MET_EXPLANATION = "Candidate's professional background is not relevant to this job."


class RankingService:
    """Score + rank parsed CVs against a job, with LLM reasoning when configured.

    A hard relevance gate runs FIRST: candidates whose professional background is
    unrelated to the job are classified ``NOT_MET`` with score 0 and never enter
    skill/experience/education/keyword/LLM scoring.
    """

    def __init__(self, settings: Settings):
        self.settings = settings

    async def rank(self, requirements: dict, profiles: list[Profile], cvs: list[dict]) -> tuple[list[dict], str]:
        relevance = [evaluate_relevance(profiles[i], requirements) for i in range(len(profiles))]
        relevant_idx = [i for i, r in enumerate(relevance) if r["classification"] != NOT_MET]

        scores_by_cv = {
            cvs[i]["id"]: score_profile(profiles[i], requirements, self.settings)
            for i in relevant_idx
        }
        llm_rankings = await self._llm_rank(requirements, [profiles[i] for i in relevant_idx])
        source = "llm" if llm_rankings is not None else "rules"

        ranked = []
        if llm_rankings:
            for k, i in enumerate(relevant_idx):
                cv = cvs[i]
                scores = scores_by_cv[cv["id"]]
                ranked.append(_relevant_entry(cv, scores, relevance[i], llm=llm_rankings[k]))
        else:
            for i in relevant_idx:
                cv = cvs[i]
                scores = scores_by_cv[cv["id"]]
                reasoning = rule_reasoning(profiles[i], requirements, scores)
                ranked.append(_relevant_entry(cv, scores, relevance[i], reasoning=reasoning))

        for i in range(len(cvs)):
            if relevance[i]["classification"] == NOT_MET:
                ranked.append(_not_met_entry(cvs[i], requirements, relevance[i]))

        # Safety net: NOT_MET candidates can never carry a non-zero score.
        for entry in ranked:
            if entry["classification"] == NOT_MET:
                entry["overall_score"] = 0.0
                entry["bucket"] = _NOT_MET_BUCKET

        ranked.sort(key=_sort_key, reverse=True)
        return ranked, source

    async def _llm_rank(self, requirements: dict, profiles: list[Profile]):
        if not self.settings.llm_enabled or not profiles:
            return None
        try:
            return await rank_with_llm(
                self.settings,
                _flatten_requirements(requirements),
                [p.as_dict() for p in profiles],
            )
        except LLMRankingError:
            return None


def _not_met_entry(cv: dict, requirements: dict, relevance: dict) -> dict:
    required = list(requirements.get("required_skills") or [])
    return {
        **cv,
        "overall_score": 0.0,
        "bucket": _NOT_MET_BUCKET,
        "recommendation": _NOT_MET_BUCKET,
        "explanation": relevance.get("reason") or _NOT_MET_EXPLANATION,
        "strengths": [],
        "weaknesses": [f"Missing required skill: {skill}" for skill in required[:6]],
        "skill_gaps": required,
        "skill_score": 0.0,
        "experience_score": 0.0,
        "education_score": 0.0,
        "certification_score": 0.0,
        "classification": NOT_MET,
        "meets_job_description": False,
        "relevance": relevance.get("relevance"),
        "relevance_score": 0.0,
        "relevance_reason": relevance.get("reason"),
        "ranked_at": _now(),
    }


def _relevant_entry(cv: dict, scores: dict, relevance: dict, llm=None, reasoning=None) -> dict:
    if llm is not None:
        overall = llm.overall
        bucket = bucket_for(overall)
        recommendation = llm.recommendation
        explanation = llm.explanation
        strengths = llm.strengths
        weaknesses = llm.weaknesses
        skill_gaps = scores["missing_required"]
    else:
        overall = scores["overall"]
        bucket = bucket_for(overall)
        recommendation = reasoning["recommendation"]
        explanation = reasoning["explanation"]
        strengths = reasoning["strengths"]
        weaknesses = reasoning["weaknesses"]
        skill_gaps = reasoning["skill_gaps"]
    return {
        **cv,
        "overall_score": overall,
        "bucket": bucket,
        "recommendation": recommendation,
        "explanation": explanation,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "skill_gaps": skill_gaps,
        "skill_score": scores["skill_score"],
        "experience_score": scores["experience_score"],
        "education_score": scores["education_score"],
        "certification_score": scores["certification_score"],
        "classification": relevance["classification"],
        "meets_job_description": relevance["meets_job_description"],
        "relevance": relevance["relevance"],
        "relevance_score": relevance["relevance_score"],
        "relevance_reason": relevance["reason"],
        "ranked_at": _now(),
    }


def _sort_key(entry: dict) -> tuple:
    not_met = 1 if entry.get("classification") == NOT_MET else 0
    return (-not_met, entry.get("overall_score") or 0.0)


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
