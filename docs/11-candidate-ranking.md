# 11 — Candidate Ranking Algorithm

## 1. Philosophy

Ranking is a **two-tier, hybrid, evidence-based** process:

1. **Deterministic heuristic tier** — fast, reproducible, explains *what* matches (skill/experience/education/certification + hidden-gem signals).
2. **LLM reasoning tier** — constrained by retrieved evidence, explains *why* and produces strengths/weaknesses/recommendation.

The final bucket (`best | strong | hidden_gem | alternative`) is decided by a **transparent scoring rule**, not by the LLM alone. The LLM explains and refines but cannot invent scores.

```
                    ┌────────────────────────────────────────────────┐
                    │          RANKING ENGINE                        │
                    │                                                │
 query/JD ──▶ 1. Parse intent ──▶ required skills, min years,       │
                    │               domain, education, certs,         │
                    │               seniority, must-have signals      │
                    │                                                │
 retrieval ──▶ 2. Per-candidate evidence pack (chunks + profile)    │
                    │                                                │
                    │  ┌──────────────────────────────────────┐      │
                    │  │ TIER 1 (deterministic, per candidate) │      │
                    │  │  skill_score        (semantic + taxonomy)│   │
                    │  │  experience_score   (years, roles, domain)│  │
                    │  │  education_score    (degree, field)       │  │
                    │  │  certification_score(certs vs required)   │  │
                    │  │  hidden_gem_score   (signals, doc 11 §5)  │  │
                    │  └──────────────────────────────────────┘      │
                    │              │                                 │
                    │              ▼                                 │
                    │  overall = weighted sum + LLM deltas           │
                    │              │                                 │
                    │              ▼                                 │
                    │  bucket assignment (thresholds + rules)        │
                    │              │                                 │
                    │              ▼                                 │
                    │  ┌──────────────────────────────────────┐      │
                    │  │ TIER 2 (LLM, bounded, evidence-only) │      │
                    │  │  strengths / weaknesses /            │      │
                    │  │  explanation / recommendation         │      │
                    │  └──────────────────────────────────────┘      │
                    └────────────────────────────────────────────────┘
```

## 2. Intent Parsing

Query is lightly processed (rule-based + optional LLM) into structured intent:

```json
{
  "required_skills": ["Flutter", "Dart"],
  "nice_to_have_skills": ["banking", "payments"],
  "min_years": 3,
  "seniority": "senior",
  "domain": "fintech",
  "education_required": null,
  "certifications_required": [],
  "must_have_signals": ["team_lead"]
}
```

## 3. Tier 1 — Deterministic Scores (all 0..1)

### 3.1 Skill Match Score
Blend of semantic + taxonomy overlap:

```
skill_match = α · Jaccard(canonical(required), canonical(candidate_skills))
            + β · mean( semantic_sim(required_skill, best_candidate_skill_chunk) )
```

- α, β from config (e.g. 0.5/0.5). Semantic sim computed from the skills/experience chunk embeddings already retrieved (cheap).
- Missing required skill → penalty; nice-to-have → bonus.

### 3.2 Experience Match Score
```
years_ratio = clamp(candidate_years / required_min_years, 0, 1.2)
domain_match = cosine(domain_descriptor, experience_chunks)   # e.g. "banking payments"
progression = fast-promotion bonus (title level increases)
experience_score = 0.5·min(years_ratio,1) + 0.3·domain_match + 0.2·progression
```

### 3.3 Education Match Score
Exact degree level match (BS/BA=0.7, MS=0.85, PhD=1.0), + field cosine if provided, + institution tier if known.

### 3.4 Certification Match Score
`matched_required / required` (0 if none required → neutral 0.5 or omitted). Certified skills (AWS, Kubernetes) get small boosts.

### 3.5 Overall Score
```
overall = Σ (w_d / Σ_active_w) · score_d        # weights renormalized over
        over active dimensions (only those with      relevant dimensions only —
        required criteria + hidden_gem bonus)        absent requirements don't
                                                     drag the score down
        + llm_delta  (bounded ±0.08, applied after Tier 2)
```
Default weights (config `ranking.weights`): skill 0.40, experience 0.30, education 0.15, certification 0.10, hidden_gem 0.05.

## 4. Bucket Assignment (transparent rules)

| Bucket | Rule |
|--------|------|
| **best** | overall ≥ 0.80 **and** required-skills coverage ≥ 0.7 |
| **strong** | overall ≥ 0.60 and required coverage ≥ 0.5 |
| **hidden_gem** | overall in 0.45–0.74 band **and** `hidden_gem_score ≥ 0.5` (high potential despite weaker surface indicators) |
| **alternative** | overall < 0.60 but non-zero retrieval relevance (still surfaced, not discarded) |

Rule order matters: check **best** → **hidden_gem** → **strong** → **alternative**. A candidate meeting both "best" and "hidden_gem" rules is classified best (its signals already raised overall).

## 5. Hidden Gem Detection (explicit model)

`hidden_gem_score` rewards **potential signals**, not years:

| Signal | Source | Weight |
|--------|--------|--------|
| Strong technical skill depth | skills taxonomy + chunk semantic score | 0.25 |
| Complex/impactful projects | project chunk keywords (scale, users, open-source stars, metrics) | 0.20 |
| Fast career progression | role titles ascending within < 2 yrs avg tenure | 0.15 |
| Relevant certifications | certs matching role cluster | 0.10 |
| Leadership evidence | responsibilities → "led", "managed", "mentored", "owned" | 0.15 |
| Open-source contributions | github url, "open source", stars/PRs | 0.10 |
| Portfolio quality | url presence + project description richness | 0.05 |

Signal extraction is a **code-level scorer** on structured fields (deterministic, auditable) with LLM assist only for phrase classification. A junior with 2 years but shipped a 5k-star OSS project and led a squad scores high → surfaced as hidden gem with a clear reason.

## 6. Tier 2 — LLM Reasoning (evidence-constrained)

Prompt structure (per candidate, batched for efficiency):

```
SYSTEM:
You are a recruiting analyst. Use ONLY the provided candidate profile and
evidence chunks. Do NOT use outside knowledge. Cite evidence chunk ids.
Return JSON: {"strengths":[...], "weaknesses":[...],
"explanation":"...", "recommendation":"...", "evidence_chunk_ids":[...]}

USER:
Job intent: {intent}
Candidate profile: {summary, skills, years_experience}
Evidence chunks:
 [c-1] (experience) "Led mobile payments squad at BankCo..."
 [c-2] (projects) "openbank-flutter-sdk — 700 GitHub stars"
```

Post-validation:
- `evidence_chunk_ids ⊆ retrieved` (else reject & regenerate once).
- Strengths/weaknesses must map to at least one chunk; generic filler flagged.
- `llm_delta` derived from LLM's suggested adjustments, clamped to ±0.08 so it can't overturn a strong heuristic.

## 7. Ranking Response Assembly

```json
{
  "bucket": "best",
  "overall_score": 0.91,
  "scores": { "skill_match": 0.94, "experience_match": 0.88,
              "education_match": 0.8, "certification_match": 0.7 },
  "strengths": ["6 yrs Flutter incl. payments", "leads squad", "OSS SDK w/ 700 stars"],
  "weaknesses": ["No AI/ML track record"],
  "explanation": "Matches 5/6 required skills; direct banking payments domain experience (c-1); shipped public SDK (c-2).",
  "recommendation": "Interview first; verify team-lead scope.",
  "evidence": [{ "chunk_id": "c-1", "section": "experience", "score": 0.93, "text": "..." }]
}
```

## 8. Determinism, Audit, Tuning

- **Reproducible**: same query + data → same ranks (temperature 0; evidence pack ordered deterministically).
- **Audit**: full `rankings` row persisted with scores, weights version, model names, evidence chunk ids, query.
- **Tuning**: weights/thresholds in config (`ranking.weights.*`); re-rank job re-evaluates; eval harness (nDCG vs recruiter labels) guides changes.
- **Fallback**: LLM unavailable → return heuristic results with `meta.reasoning="heuristic"` (buckets still valid, just no narrative).

## 9. Anti-Bias Guardrails

- Hidden-gem path explicitly counteracts years-of-experience bias.
- Skill match uses semantic similarity, not raw keyword presence (reduces literal keyword over-optimization).
- Optional bias checks: report score distribution by demographic proxy fields when available; flag if `overall` strongly correlates with protected attributes (future feature, doc 14).
