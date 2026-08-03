from __future__ import annotations

import re
from collections import defaultdict

CANONICAL_ALIASES: dict[str, str] = {
    "docker": "docker",
    "docker.io": "docker",
    "dockers": "docker",
    "kubernetes": "kubernetes",
    "k8s": "kubernetes",
    "kube": "kubernetes",
    "typescript": "typescript",
    "ts": "typescript",
    "javascript": "javascript",
    "js": "javascript",
    "react": "react",
    "react.js": "react",
    "reactjs": "react",
    "node": "node.js",
    "nodejs": "node.js",
    "postgresql": "postgresql",
    "postgres": "postgresql",
    "pg": "postgresql",
}

_STOPWORDS = {"and", "the", "of", "with", "for", "in", "on", "to", "a", "an"}


def slugify(name: str) -> str:
    name = name.lower().strip()
    name = re.sub(r"[^a-z0-9.#+]+", " ", name)
    parts = [p for p in name.split() if p not in _STOPWORDS]
    return " ".join(parts)


def canonical_skill(name: str) -> str:
    return CANONICAL_ALIASES.get(slugify(name), slugify(name))


class SkillNormalizer:
    def __init__(self, aliases: dict[str, str] | None = None) -> None:
        self._alias_map = aliases or CANONICAL_ALIASES
        self._seen: dict[str, set[str]] = defaultdict(set)

    def normalize(self, skills: list[str]) -> list[str]:
        out: list[str] = []
        for raw in skills:
            canon = self._alias_map.get(slugify(raw), slugify(raw))
            if canon and canon not in out:
                out.append(canon)
                self._seen[canon].add(slugify(raw))
        return out

    def canonical_of(self, raw: str) -> str:
        return self._alias_map.get(slugify(raw), slugify(raw))

    def seen_aliases(self, canon: str) -> set[str]:
        return set(self._seen.get(canon, set()))


class YearsExperienceCalculator:
    def total_years(self, ranges: list[object]) -> float:
        """ranges: list of DateRange-like objects with .years()."""
        return round(sum(r.years() for r in ranges), 2)

    def avg_tenure(self, ranges: list[object]) -> float:
        if not ranges:
            return 0.0
        return round(self.total_years(ranges) / len(ranges), 2)

    def fast_progression(self, positions: list[str]) -> bool:
        """Heuristic: junior→senior titles ascending within short tenures."""
        order = {
            "intern": 0,
            "junior": 1,
            "developer": 2,
            "engineer": 2,
            "software engineer": 2,
            "mid": 2,
            "senior": 3,
            "staff": 4,
            "principal": 4,
            "lead": 4,
            "manager": 4,
        }

        def level(title: str) -> int:
            low = title.lower()
            best = 0
            for key, val in order.items():
                if key in low:
                    best = max(best, val)
            return best

        levels = [level(p) for p in positions]
        rising = [levels[i] > levels[i - 1] for i in range(1, len(levels)) if levels[i - 1] > 0]
        return len(rising) >= 1 and sum(rising) / max(len(rising), 1) >= 0.5
