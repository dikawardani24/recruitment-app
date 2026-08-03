from __future__ import annotations

from dataclasses import dataclass, field
from uuid import UUID

from app.core.config import RankingWeights
from app.domain.entities import Candidate, VectorHit
from app.domain.services import YearsExperienceCalculator


@dataclass(frozen=True)
class SearchIntent:
    required_skills: list[str] = field(default_factory=list)
    nice_to_have_skills: list[str] = field(default_factory=list)
    min_years: float = 0.0
    seniority: str | None = None
    domain: str | None = None
    education_required: str | None = None
    certifications_required: list[str] = field(default_factory=list)
    must_have_signals: list[str] = field(default_factory=list)


@dataclass
class Tier1Scores:
    skill: float = 0.0
    experience: float = 0.0
    education: float = 0.0
    certification: float = 0.0
    hidden_gem: float = 0.0
    overall: float = 0.0
    skill_coverage: float = 0.0


_HIDDEN_GEM_SIGNALS = {
    "led": 1.0,
    "lead": 1.0,
    "managed": 1.0,
    "mentor": 1.0,
    "owned": 0.8,
    "architected": 1.0,
    "designed": 0.6,
}


class RankingEngine:
    """Tier-1 deterministic scoring + bucket assignment (doc 11)."""

    def __init__(self, weights: RankingWeights, years: YearsExperienceCalculator) -> None:
        self.w = weights
        self.years = years

    def compute_tier1(
        self,
        candidate: Candidate,
        intent: SearchIntent,
        hits: list[VectorHit],
    ) -> Tier1Scores:
        s = Tier1Scores()
        s.skill = self._skill_score(candidate, intent)
        s.experience = self._experience_score(candidate, intent, hits)
        s.education = self._education_score(candidate, intent)
        s.certification = self._certification_score(candidate, intent)
        s.hidden_gem = self._hidden_gem_score(candidate, hits)
        s.skill_coverage = self._skill_coverage(candidate, intent)

        s.overall = self._overall(intent, s)
        return s

    def _overall(self, intent: SearchIntent, s: Tier1Scores) -> float:
        """Weighted sum over *relevant* dimensions only.

        Dimensions with no required criteria (e.g. no education requirement)
        are excluded so they cannot drag the overall score down.
        """
        active: list[tuple[float, float]] = []
        if intent.required_skills or intent.nice_to_have_skills:
            active.append((self.w.skill, s.skill))
        if intent.min_years > 0 or intent.domain or intent.seniority:
            active.append((self.w.experience, s.experience))
        if intent.education_required:
            active.append((self.w.education, s.education))
        if intent.certifications_required:
            active.append((self.w.certification, s.certification))
        active.append((self.w.hidden_gem, s.hidden_gem))

        total_w = sum(w for w, _ in active)
        if total_w == 0:
            return round(s.skill, 3)
        overall = sum((w / total_w) * v for w, v in active)
        return round(overall, 3)

    def assign_bucket(self, scores: Tier1Scores) -> str:
        if scores.overall >= self.w.bucket_best and scores.skill_coverage >= 0.7:
            return "best"
        if (
            self.w.bucket_hidden_gem <= scores.overall <= self.w.bucket_hidden_gem_high
            and scores.hidden_gem >= self.w.hidden_gem_min_score
        ):
            return "hidden_gem"
        if scores.overall >= self.w.bucket_strong and scores.skill_coverage >= 0.5:
            return "strong"
        return "alternative"

    # -- sub-scores -----------------------------------------------------

    def _skill_score(self, candidate: Candidate, intent: SearchIntent) -> float:
        if not intent.required_skills:
            return 0.5
        have = {s.lower() for s in candidate.profile.skills}
        required = [s.lower() for s in intent.required_skills]
        hit = sum(1 for r in required if r in have)
        coverage = hit / len(required)
        bonus = sum(1 for n in intent.nice_to_have_skills if n.lower() in have) * 0.05
        return round(min(1.0, coverage * 0.8 + bonus), 3)

    def _skill_coverage(self, candidate: Candidate, intent: SearchIntent) -> float:
        if not intent.required_skills:
            return 1.0
        have = {s.lower() for s in candidate.profile.skills}
        required = [s.lower() for s in intent.required_skills]
        return round(sum(1 for r in required if r in have) / len(required), 3)

    def _experience_score(
        self,
        candidate: Candidate,
        intent: SearchIntent,
        hits: list[VectorHit],
    ) -> float:
        ranges = [e.date_range() for e in candidate.profile.experience]
        years = self.years.total_years(ranges)

        required = max(intent.min_years, 1.0)
        years_ratio = min(years / required, 1.2)
        years_part = min(years_ratio, 1.0)

        domain_part = 0.0
        if intent.domain:
            exp_hits = [h for h in hits if h.section.value == "experience"]
            if exp_hits:
                domain_part = sum(h.score for h in exp_hits[:3]) / max(len(exp_hits[:3]), 1)

        positions = [e.position for e in candidate.profile.experience]
        progression = 1.0 if self.years.fast_progression(positions) else 0.0

        return round(0.5 * years_part + 0.3 * domain_part + 0.2 * progression, 3)

    def _education_score(self, candidate: Candidate, intent: SearchIntent) -> float:
        if not intent.education_required or not candidate.profile.education:
            return 0.5
        level = {"bsc": 0.7, "bs": 0.7, "ba": 0.7, "msc": 0.85, "ms": 0.85, "ma": 0.85, "phd": 1.0}
        required = level.get(intent.education_required.lower(), 0.5)
        top = 0.0
        for edu in candidate.profile.education:
            got = level.get((edu.degree or "").lower().replace(".", ""), 0.5)
            top = max(top, got)
        return round(min(1.0, top / required) if required else 0.5, 3)

    def _certification_score(self, candidate: Candidate, intent: SearchIntent) -> float:
        if not intent.certifications_required:
            return 0.5
        have = [self._cert_name(c).lower() for c in candidate.profile.certifications]
        required = [r.lower() for r in intent.certifications_required]
        if not required:
            return 0.5
        matched = sum(1 for r in required if any(r in h for h in have))
        return round(matched / len(required), 3)

    @staticmethod
    def _cert_name(cert) -> str:  # type: ignore[no-untyped-def]
        if isinstance(cert, str):
            return cert
        if isinstance(cert, dict):
            return cert.get("name", "")
        return getattr(cert, "name", "")

    def _hidden_gem_score(self, candidate: Candidate, hits: list[VectorHit]) -> float:
        m = candidate.derived_metrics
        signals: list[tuple[float, float]] = []

        skill_depth = min(1.0, m.get("skill_count", 0) / 15.0)
        signals.append((0.25, skill_depth))

        project_strength = self._project_strength(candidate)
        signals.append((0.20, project_strength))

        fast = 1.0 if self.years.fast_progression([e.position for e in candidate.profile.experience]) else 0.0
        signals.append((0.15, fast))

        signals.append((0.10, 1.0 if candidate.profile.certifications else 0.0))

        leadership = self._leadership_evidence(candidate)
        signals.append((0.15, min(1.0, leadership / 2.0)))

        oss = self._opensource_evidence(candidate)
        signals.append((0.10, oss))

        portfolio = 1.0 if any(p.url for p in candidate.profile.projects) else 0.0
        signals.append((0.05, portfolio))

        return round(sum(w * v for w, v in signals), 3)

    @staticmethod
    def _project_strength(candidate: Candidate) -> float:
        if not candidate.profile.projects:
            return 0.0
        total = 0.0
        for p in candidate.profile.projects:
            text = f"{p.description} {' '.join(p.highlights)}".lower()
            score = 0.3
            for token in ("star", "users", "scale", "million", "thousand", "1000+", "50k"):
                if token in text:
                    score += 0.2
            total += min(score, 1.0)
        return min(1.0, total / max(len(candidate.profile.projects), 1))

    @staticmethod
    def _leadership_evidence(candidate: Candidate) -> int:
        count = 0
        for e in candidate.profile.experience:
            for r in e.responsibilities:
                low = r.lower()
                for token, weight in _HIDDEN_GEM_SIGNALS.items():
                    if token in low:
                        count += 1
                        break
        return count

    @staticmethod
    def _opensource_evidence(candidate: Candidate) -> float:
        for p in candidate.profile.projects:
            if p.url and "github.com" in p.url:
                return 1.0
        return 0.0


def bucket_rank(bucket: str) -> int:
    order = {"best": 0, "strong": 1, "hidden_gem": 2, "alternative": 3}
    return order.get(bucket, 3)
