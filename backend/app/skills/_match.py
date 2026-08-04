from __future__ import annotations

import re

TECH_SKILLS: list[str] = [
    "python", "java", "javascript", "typescript", "golang", "go", "c++", "c#", "ruby",
    "php", "kotlin", "swift", "rust", "scala", "shell", "bash", "sql", "nosql",
    "react", "react native", "angular", "vue", "next.js", "node.js", "django", "flask",
    "fastapi", "spring", "spring boot", "laravel", "rails", "asp.net", "graphql", "grpc",
    "rest", "restful", "kafka", "rabbitmq", "redis", "elasticsearch", "mongodb",
    "postgresql", "mysql", "oracle", "sql server", "dynamodb", "cassandra",
    "docker", "kubernetes", "k8s", "terraform", "ansible", "jenkins", "ci/cd",
    "aws", "azure", "gcp", "google cloud", "lambda", "serverless", "cloud",
    "tensorflow", "pytorch", "keras", "scikit-learn", "pandas", "numpy", "spark",
    "hadoop", "airflow", "ml", "machine learning", "deep learning", "nlp",
    "llm", "rag", "langchain", "computer vision", "opencv",
    "html", "css", "sass", "tailwind", "flutter", "dart", "react native",
    "android", "ios", "xcode", "kotlin", "swift",
    "git", "github", "gitlab", "jira", "confluence", "agile", "scrum",
    "linux", "unix", "windows", "networking", "vpn", "firewall",
    "selenium", "pytest", "junit", "jest", "cypress", "test", "qa", "tdd",
    "microservices", "soap", "oauth", "jwt", "security", "cybersecurity", "cryptography",
    "excel", "power bi", "tableau", "looker", "analytics", "etl", "data pipeline",
    "figma", "sketch", "ui", "ux", "prototyping", "wireframing", "user research",
    "express", "nestjs", "prisma", "typeorm", "sequelize", "redux", "zustand",
    "vite", "webpack", "npm", "yarn", "pnpm", "bun", "deno", "nuxt", "bootstrap",
    "material ui", "chakra ui", "django rest framework", "sqlalchemy", "celery",
    "snowflake", "bigquery", "dbt", "redshift", "databricks",
    "prometheus", "grafana", "helm", "istio", "opentelemetry",
    "firebase", "supabase", "vercel", "react query",
    "llamaindex", "chromadb", "pinecone", "qdrant", "pgvector", "vector database",
    "prompt engineering", "maven", "gradle", "apollo", "socket.io",
]

SOFT_SKILLS: list[str] = [
    "communication", "leadership", "teamwork", "collaboration", "problem solving",
    "critical thinking", "creativity", "adaptability", "time management", "agile",
    "ownership", "initiative", "mentoring", "stakeholder management", "presentation",
    "negotiation", "empathy", "resilience", "attention to detail", "writing",
    "cross-functional", "self-starter", "detail-oriented", "growth mindset",
    "accountability", "prioritization", "planning", "documentation",
]

CERT_KEYWORDS: list[tuple[str, ...]] = [
    ("AWS Certified", "aws certified", "aws solutions architect", "aws developer"),
    ("Azure Certified", "azure certified", "azure administrator", "azure developer"),
    ("Google Cloud Certified", "gcp certified", "google cloud certified"),
    ("PMP", "pmp", "project management professional"),
    ("CISSP", "cissp"),
    ("CKA", "cka", "certified kubernetes administrator"),
    ("SCEA", "scea", "sun certified enterprise architect"),
    ("CISM", "cism"),
    ("CEH", "ceh", "certified ethical hacker"),
    ("CompTIA+", "comptia"),
    ("Salesforce Certified", "salesforce certified"),
    ("CPA", "cpa", "certified public accountant"),
    ("CFA", "cfa", "chartered financial analyst"),
]

SKILL_MAP: dict[str, list[str]] = {s: [s] for s in TECH_SKILLS + SOFT_SKILLS}
# multi-word canonical skills also match their abbreviations / synonyms
SKILL_MAP["machine learning"] += ["ml"]
SKILL_MAP["kubernetes"] += ["k8s"]
SKILL_MAP["golang"] += ["go"]
SKILL_MAP["c++"] += ["cpp"]
SKILL_MAP["typescript"] += ["ts"]
SKILL_MAP["javascript"] += ["js"]
SKILL_MAP["react"] += ["reactjs"]
SKILL_MAP["node.js"] += ["node", "nodejs"]
SKILL_MAP["next.js"] += ["nextjs"]
SKILL_MAP["vue"] += ["vue.js", "vuejs"]
SKILL_MAP["postgresql"] += ["postgres"]
SKILL_MAP["ci/cd"] += ["cicd", "ci cd"]
SKILL_MAP["django rest framework"] += ["drf"]
SKILL_MAP["material ui"] += ["mui"]
SKILL_MAP["express"] += ["express.js", "expressjs"]
SKILL_MAP["react query"] += ["tanstack query"]
SKILL_MAP["google cloud"] += ["gcp"]

_WORD_BOUNDARY = re.compile(r"[\W_]+")
_SIMPLE_TOKEN = re.compile(r"^[\w ]+$")


def _tokenize(text: str) -> str:
    return " " + _WORD_BOUNDARY.sub(" ", text.lower()) + " "


def _in_text(raw_low: str, corpus: str, token: str) -> bool:
    if _SIMPLE_TOKEN.match(token):
        return f" {token} " in corpus
    return bool(re.search(rf"(?<![\w]){re.escape(token)}(?![\w])", raw_low))


# token -> canonical skill name (only real aliases; canonical self-mappings skipped)
_ALIAS_TO_CANONICAL: dict[str, str] = {}
for _canonical, _aliases in SKILL_MAP.items():
    for _alias in _aliases:
        if _alias != _canonical:
            _ALIAS_TO_CANONICAL[_alias] = _canonical


def find_skills(text: str, allowed: list[str] | None = None) -> list[str]:
    """Return canonical skill names found in ``text``.

    Matches canonical names and their aliases (e.g. ``postgres`` -> ``postgresql``,
    ``js`` -> ``javascript``, ``ml`` -> ``machine learning``, ``k8s`` -> ``kubernetes``).
    """
    if not text:
        return []
    raw_low = text.lower()
    corpus = _tokenize(text)
    found: list[str] = []
    for skill in (allowed or (TECH_SKILLS + SOFT_SKILLS)):
        canonical = _ALIAS_TO_CANONICAL.get(skill, skill)
        if canonical != skill:
            continue  # pure alias; resolved via its canonical skill
        if skill in found:
            continue
        if any(_in_text(raw_low, corpus, a) for a in SKILL_MAP.get(skill, [skill])):
            found.append(skill)
    return found


_FILLER_WORDS = {
    "a", "an", "the", "and", "or", "of", "to", "for", "with", "in", "on", "at",
    "as", "is", "are", "be", "by", "from", "using", "use", "used",
}
_NOISE_WORDS = {
    "experience", "experienced", "years", "year", "degree", "education",
    "certification", "certifications", "responsibilities", "responsibility",
    "summary", "about", "company", "role", "position", "job", "title",
    "description", "requirements", "qualifications", "preferred", "required",
    "nice", "have", "must", "strong", "solid", "good", "excellent", "working",
    "work", "skills", "skill", "ability", "abilities", "understanding",
    "familiarity", "knowledge", "plus", "minimum", "mandatory", "desired",
    "what", "you", "will", "join", "our", "team",
}
_ACTION_VERBS = {
    "build", "develop", "design", "implement", "maintain", "operate", "manage",
    "lead", "create", "ensure", "support", "help", "deliver", "own",
    "collaborate", "write", "test", "analyze", "review", "improve", "optimize",
    "architect", "coordinate", "provide", "drive", "mentor", "conduct",
    "document", "troubleshoot", "deploy", "automate", "monitor", "debug",
    "scale", "prototype", "ship", "use", "using", "understand", "work",
}
_ROLE_WORDS = {
    "backend", "frontend", "fullstack", "full-stack", "engineer", "engineering",
    "developer", "designer", "manager", "analyst", "scientist", "architect",
    "lead", "senior", "junior", "intern", "recruiter", "consultant", "specialist",
}


def _covered_by_known_skill(item: str) -> bool:
    """True if the item already contains a known skill or alias (word-boundary)."""
    for aliases in SKILL_MAP.values():
        for alias in aliases:
            if _SIMPLE_TOKEN.match(alias):
                if re.search(rf"(?<![\w]){re.escape(alias)}(?![\w])", item):
                    return True
            elif alias in item:
                return True
    return False


def skill_like_terms(text: str) -> list[str]:
    """Open-vocabulary skill candidates found in ``text`` (dictionary miss).

    Returns lower-cased terms that look like skills but are not in the skill
    dictionary, e.g. ``haskell``, ``couchbase``, ``distributed systems``.
    """
    if not text:
        return []
    seen: set[str] = set()
    out: list[str] = []
    for raw in re.split(r"[\n,;•·・•]", text):
        item = re.sub(r"^[\s#\-*•◦▪▫·・]+", "", raw).strip().strip(":.,()[]")
        if not item or len(item) < 2 or len(item) > 48:
            continue
        words = item.split()
        if len(words) > 4:
            continue
        low = item.lower()
        if re.search(r"\d", low):
            continue
        low_words = [w.lower() for w in words]
        if any(w in _NOISE_WORDS for w in low_words):
            continue
        if low_words[0] in _ACTION_VERBS or low_words[0] in ("and", "or"):
            continue
        if all(w in _FILLER_WORDS or w in _ROLE_WORDS for w in low_words):
            continue
        if _covered_by_known_skill(low):
            continue
        if low not in seen:
            seen.add(low)
            out.append(low)
    return out


def find_certifications(text: str) -> list[str]:
    out: list[str] = []
    low = text.lower()
    for group in CERT_KEYWORDS:
        canonical, *aliases = group
        for alias in aliases:
            if alias in low:
                if canonical not in out:
                    out.append(canonical)
                break
    return out
