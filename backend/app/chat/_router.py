from __future__ import annotations

import re
from dataclasses import dataclass

"""Deterministic query router for the recruiter copilot.

Classifies every user question WITHOUT calling the LLM. Gemini is a scarce
resource (~5 RPM), so the copilot decides up front how the question must be
answered:

- ``deterministic`` -> answerable from workspace data via API tools only. ZERO
  Gemini calls.
- ``rag_reasoning``  -> needs workspace data plus natural-language reasoning. The
  orchestration layer fetches data first, then makes exactly ONE Gemini call.
- ``general``        -> general-knowledge / off-topic chitchat. One Gemini call,
  no tools, no RAG evidence.
- ``chitchat``       -> greetings / thanks. Answered deterministically, ZERO
  Gemini calls.

Intent priority matters: stats/ranking/comparison/requirements-queries beat the
generic ``candidate_search`` catch-all, and advice-style general questions win
over workspace wording (e.g. "how should I write a good job description?" is
general, while "match this job description" is data). When a question is still
ambiguous it defaults to ``rag_reasoning`` (safe: grounded) rather than skipping
retrieval.
"""


@dataclass(frozen=True)
class QueryRoute:
    mode: str  # "deterministic" | "rag_reasoning" | "general" | "chitchat"
    intent: str
    reason: str
    search_query: str | None = None
    keywords: tuple[str, ...] = ()
    job_ref: str | None = None  # explicit job id if mentioned (job-…) or None
    score_filter: tuple[str, float] | None = None  # e.g. (">=", 0.8) for "above 80"

    def as_dict(self) -> dict:
        return {
            "use_rag": self.mode in ("deterministic", "rag_reasoning"),
            "mode": self.mode,
            "intent": self.intent,
            "reason": self.reason,
            "search_query": self.search_query,
            "score_filter": self.score_filter,
        }


_GREETING = re.compile(
    r"^\s*(hi|hello|hey|yo|greetings|good (morning|afternoon|evening))\b[!.?]*\s*$",
    re.I,
)
_THANKS = re.compile(r"^\s*(thanks|thank you|thx|ty)\b[!.?]*\s*$", re.I)

# Question business-intent patterns. Ordered by priority: more specific intents
# win over the ``candidate_search`` catch-all at the bottom.
_WORKSPACE_PATTERNS: list[tuple[str, re.Pattern]] = [
    # application statistics
    (
        "application_statistics",
        re.compile(
            r"\b(how many|total|count of)\s+(candidates?|applicants?|"
            r"jobs?|applications?|cvs|people)\b",
            re.I,
        ),
    ),
    # ranking: best / top / rank / strong match for a role (or between people)
    (
        "candidate_ranking",
        re.compile(
            r"\b(candidates?|applicants?)\b.{0,12}\b(match|matches|fit|fits|"
            r"ranking|ranked?|top|strongest|most suitable|suitable)\b|"
            r"\b(best|top|strongest|most suitable)\b.{0,12}\b(candidate|applicant|"
            r"match|fit|suitable)\b|"
            r"\b(good|best|strong|great)\s+(match|fit)\b|"
            r"\b(rank|ranked|ranking|rankings)\b",
            re.I,
        ),
    ),
    # comparison between workspace people
    (
        "candidate_comparison",
        re.compile(
            r"\b(compare|comparing|comparison)\b.{0,25}\b(candidates?|applicants?|"
            r"jobs?|positions?)\b|"
            r"\b(difference between|vs\.?)\b.{0,20}\b(candidates?|applicants?)\b",
            re.I,
        ),
    ),
    # requirement matching / qualifications
    (
        "job_requirement_matching",
        re.compile(
            r"\b(meet|meets|met|satisf(y|ies|ied)|qualif(y|ies|ied))\b.{0,25}\b"
            r"(requirement|requirements|job|role|position|candidate|applicant)\b|"
            r"\b(requirements?)\b.{0,25}\b(meet|satisfy|qualified|match)\b",
            re.I,
        ),
    ),
    # a specific candidate by id or demonstrative reference
    (
        "candidate_detail",
        re.compile(
            r"\b(cv-[\w-]+)\b|"
            r"\b(this|that|the)\s+(candidate|applicant)\b",
            re.I,
        ),
    ),
    # generic candidate/applicant search — the catch-all.
    (
        "candidate_search",
        re.compile(
            r"\b(candidates?|applicants?|applied|applications?|cvs|resumes)\b|"
            r"\bwho\b.{0,25}\b(has|have|applied)\b",
            re.I,
        ),
    ),
    # a specific stored job / its description or requirements
    (
        "job_detail",
        re.compile(
            r"\b(this|the|our|that)\s+\w*\s*(job|role|position|vacancy|opening)\b|"
            r"\b(this|the|our|that)\s+(job\s+)?(description|posting|requirements?)\b|"
            r"\b(requirements?|description)?\s*(of|for)\s+(the|this|our)?\s*\w*"
            r"\s*(job|role|position|vacancy)\b",
            re.I,
        ),
    ),
    # job existence / listing
    (
        "job_search",
        re.compile(
            r"\b(list|show|find|any|are there|do we have|which)\b.{0,20}\b"
            r"(job|jobs|posting|postings|position|positions|vacancy|opening|"
            r"vacancies|developer|developers|engineer|engineers)\b",
            re.I,
        ),
    ),
]

# General-knowledge patterns. Only evaluated when no workspace pattern hit.
_GENERAL_PATTERNS: list[re.Pattern] = [
    re.compile(r"^\s*(what is|what are|what'?s a|define|explain|describe|meaning of)\b", re.I),
    re.compile(r"\b(difference between| vs\.? | versus\b)", re.I),
    re.compile(r"\bhow does \w+ work\b", re.I),
    re.compile(r"\bhow (do|should|can|could) (i|you|we)\b", re.I),
    re.compile(r"\btips? (for|on|to)\b|\bbest practices\b", re.I),
    re.compile(r"\bhow to\b", re.I),
    re.compile(r"\bwhat (skills|tools|technologies|language|framework)s? should\b", re.I),
    re.compile(r"\b(is|are|would) \w+ better\b|\bshould (i|you|we) use\b", re.I),
    re.compile(r"\brecommend(ation)? (a|an|the)|\bsuggest(ion)? (a|an|the)\b", re.I),
]

_STOPWORDS = frozenset(
    """
    a an the this that these those our your my we us i you they them it he she
is are was were be been being do does did have has had having any some
    many much no none not for with about behind below between during including
    inside into near of off on onto out over through to toward under up upon
    within without who which what when where why how can could shall should will
    would may might must own are there here please tell me give show find list
    need want ask question regarding concerning candidate candidates applicant
    applicants applied cv cvs resume resumes job jobs position role posting
    vacancy opening description details detail profile requirements experience
    skills skill year years match ranking ranked best top suitable qualified
    developer developers engineer engineers their his her its mine yours ours
    theirs themselves above over below under greater than lower higher more less
    least atmost score scores points percent match score threshold dev
        """.split()
)

_ENTITY_ID = re.compile(r"\b(job-[\w-]+|cv-[\w-]+)\b", re.I)


def _extract_keywords(text: str) -> tuple[str, ...]:
    """Extract substantive topic keywords (skill / product / title words) the
    deterministic answerer uses to filter jobs and candidates."""
    cleaned = re.sub(r"[^a-z0-9\s+\-\.]", " ", text.lower()).replace("_", " ")
    seen: set[str] = set()
    out: list[str] = []
    for raw in re.split(r"[\s,]+", cleaned):
        token = raw.strip()
        if not token or token in _STOPWORDS or token.isdigit() or len(token) < 3:
            continue
        if token.startswith(("job-", "cv-", "id-")) or re.fullmatch(
            r"[a-z0-9]{8,}", token
        ):
            continue
        stem = token.rstrip("s") if token.endswith("s") else token
        if stem in seen:
            continue
        seen.add(stem)
        out.append(token)
        if len(out) >= 5:
            break
    return tuple(out)


def _build_search_query(intent: str, keywords: tuple[str, ...], text: str) -> str | None:
    if not keywords:
        return None
    terms = " ".join(keywords)
    if intent == "candidate_search":
        return f"candidates with {terms} experience"
    if intent == "job_search":
        return f"jobs for {terms}"
    if intent == "job_detail":
        return f"job posting {terms} requirements"
    if intent == "candidate_ranking":
        return f"candidates ranking for {terms} job"
    if intent in ("candidate_comparison", "job_requirement_matching"):
        return f"{terms} candidates requirements"
    return terms


_DETERMINISTIC_INTENTS = {
    "application_statistics",
    "candidate_search",
    "job_search",
    "job_detail",
    "candidate_ranking",
}

_FOLLOWUP_HINTS = re.compile(
    r"\b(what about|how about|and\b|them|these|those|it|that one|others?|"
    r"the rest|they|their)\b",
    re.I,
)

# Score-threshold phrases, e.g. "candidates above 80", "score over 75",
# "more than 70". "above/over/at least" is inclusive; "more/greater/higher
# than" is strict.
_AT_LEAST_SCORE = re.compile(
    r"\b(above|over|at least|no less than|>=)\s*(\d{1,3})\b", re.I
)
_STRICT_MORE_SCORE = re.compile(
    r"\b(more than|greater than|higher than|>)\s*(\d{1,3})\b", re.I
)
_BELOW_SCORE = re.compile(
    r"\b(below|under|less than|at most|no more than|lower than|<=)\s*(\d{1,3})\b",
    re.I,
)
_STRICT_ABOVE = re.compile(r">\s*(\d{1,3})\b", re.I)


def _normalize_score(value: float) -> float:
    return min(1.0, max(0.0, value / 100.0 if value > 1 else value))


def _extract_score(text: str) -> tuple[str, float] | None:
    match = _AT_LEAST_SCORE.search(text)
    if match:
        return ">=", _normalize_score(float(match.group(2)))
    match = _STRICT_MORE_SCORE.search(text)
    if match:
        return ">", _normalize_score(float(match.group(2)))
    match = _BELOW_SCORE.search(text)
    if match:
        return "<=", _normalize_score(float(match.group(2)))
    match = _STRICT_ABOVE.search(text)
    if match:
        return ">", _normalize_score(float(match.group(1)))
    return None


class QueryRouter:
    @staticmethod
    def route(question: str, history: list[dict] | None = None) -> QueryRoute:
        text = (question or "").strip()
        if not text:
            return QueryRoute("general", "general_question", "Empty or missing question.")

        if _GREETING.match(text):
            return QueryRoute(
                "chitchat", "general_question", "Greeting, answered deterministically."
            )
        if _THANKS.match(text):
            return QueryRoute(
                "chitchat", "general_question", "Acknowledgement, answered deterministically."
            )

        lower = text.lower()
        job_ref = _interrogative_id(lower)
        score = _extract_score(text)

        # A short follow-up (pronouns / "what about X") after a data conversation
        # stays grounded: it refers to workspace entities from earlier turns, so
        # we carry the previous question's intent forward.
        if history and len(text.split()) <= 6 and _FOLLOWUP_HINTS.search(lower):
            prev = _previous_user_route(history)
            if prev is not None:
                keywords = _extract_keywords(text) or prev.keywords
                mode = "deterministic" if prev.intent in _DETERMINISTIC_INTENTS else "rag_reasoning"
                return QueryRoute(
                    mode,
                    prev.intent,
                    "Follow-up continues the previous workspace query.",
                    search_query=_build_search_query(prev.intent, keywords, text),
                    keywords=keywords,
                    job_ref=prev.job_ref if prev.job_ref else job_ref,
                    score_filter=score or prev.score_filter,
                )
            return QueryRoute(
                "rag_reasoning",
                "other",
                "Follow-up continues an earlier workspace-data conversation.",
                search_query=_followup_query(history),
                keywords=(),
                job_ref=job_ref,
            )

        intent: str | None = None
        for candidate, pattern in _WORKSPACE_PATTERNS:
            if pattern.search(lower):
                intent = candidate
                break

        if intent is None:
            if any(p.search(lower) for p in _GENERAL_PATTERNS):
                return QueryRoute(
                    "general",
                    "general_question",
                    "General-knowledge question; answered directly without retrieval.",
                    keywords=_extract_keywords(text),
                )
            keywords = _extract_keywords(text)
            return QueryRoute(
                "rag_reasoning",
                "other",
                "Question is ambiguous; using workspace-grounded reasoning.",
                search_query=_build_search_query("other", keywords, text),
                keywords=keywords,
                job_ref=job_ref,
            )

        keywords = _extract_keywords(text)

        # A score threshold only ever refers to candidate ranking scores, so a
        # "find me X developer with score > N" question is about people, not
        # about listing job postings.
        if score is not None and intent in ("job_search", "job_detail"):
            intent = "candidate_search"

        mode = "deterministic" if intent in _DETERMINISTIC_INTENTS else "rag_reasoning"
        return QueryRoute(
            mode,
            intent,
            f"Question maps to workspace intent '{intent}'.",
            search_query=_build_search_query(intent, keywords, text),
            keywords=keywords,
            job_ref=job_ref,
            score_filter=score,
        )


def _interrogative_id(text: str) -> str | None:
    match = _ENTITY_ID.search(text)
    if match and match.group(0).startswith("job-"):
        return match.group(0)
    return None


def _previous_user_route(history: list[dict] | None) -> QueryRoute | None:
    for turn in reversed(history or []):
        if turn.get("role") == "user" and turn.get("content"):
            return QueryRouter.route(turn["content"])
    return None


def _followup_query(history: list[dict]) -> str | None:
    for turn in reversed(history or []):
        if turn.get("role") == "user" and turn.get("content"):
            keywords = _extract_keywords(turn["content"])
            return _build_search_query("other", keywords, turn["content"])
    return None


router = QueryRouter()