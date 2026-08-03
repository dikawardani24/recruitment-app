from __future__ import annotations

import re

from app.application.ranking.ranking_engine import SearchIntent

_YEAR_PATTERN = re.compile(r"(\d+)\s*\+?\s*(?:years?|yrs?)", re.IGNORECASE)
_SENIORITY = {"junior", "mid", "senior", "staff", "principal", "lead"}


class IntentParser:
    """Lightweight rule-based query → SearchIntent (v1, doc 11 §2)."""

    def parse(self, query: str) -> SearchIntent:
        tokens = query.lower()
        min_years = 0.0
        m = _YEAR_PATTERN.search(tokens)
        if m:
            min_years = float(m.group(1))

        seniority = None
        for s in _SENIORITY:
            if re.search(rf"\b{s}\b", tokens):
                seniority = s
                break

        domain = None
        for d in ("banking", "fintech", "healthcare", "e-commerce", "ecommerce", "gaming", "mobile", "ai", "security"):
            if re.search(rf"\b{d}\b", tokens):
                domain = d
                break

        return SearchIntent(
            min_years=min_years,
            seniority=seniority,
            domain=domain,
        )

    def extract_skills(self, query: str, known_skills: list[str]) -> list[str]:
        """Match query tokens against the canonical skill taxonomy."""
        low = query.lower()
        return [s for s in known_skills if re.search(rf"\b{re.escape(s.lower())}\b", low)]
