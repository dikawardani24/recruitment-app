from __future__ import annotations

import json as _json

from app.jd._structure import structure_jd
from app.skills import dedupe, skill_tokens


class RequirementParser:
    """Normalize a job description (JSON or plain text) into the standard requirements schema."""

    def parse(self, text: str) -> dict | None:
        text = text.strip()
        if not text:
            return None
        requirements = self._from_json(text) if text.startswith("{") else None
        if requirements is None:
            requirements = structure_jd(text)
        return requirements

    def _from_json(self, text: str) -> dict | None:
        try:
            data = _json.loads(text)
            if not isinstance(data, dict):
                return None
        except (_json.JSONDecodeError, ValueError):
            return None

        # Normalize various JSON field names into the standard schema.
        def _list(key: str, *alts: str) -> list[str]:
            for k in (key, *alts):
                val = data.get(k)
                if isinstance(val, list):
                    return [str(s).strip() for s in val if str(s).strip()]
            return []

        def _float(key: str, *alts: str) -> float:
            for k in (key, *alts):
                val = data.get(k)
                if val is not None:
                    try:
                        return float(val)
                    except (TypeError, ValueError):
                        pass
            return 0.0

        def _str(key: str, *alts: str) -> str | None:
            for k in (key, *alts):
                val = data.get(k)
                if isinstance(val, str) and val.strip():
                    return val.strip()
            return None

        # Merge skill lists from various possible keys.
        # Full-sentence qualifications (e.g. "Experience building mobile apps...")
        # are reduced to real skill tokens so the rule engine can match them.
        required_skills = skill_tokens(
            _list("required_skills", "requiredQualifications", "mustHave", "must_have", "requirements")
        )
        preferred_skills = skill_tokens(
            _list("preferred_skills", "preferredQualifications", "niceToHaveSkills", "niceToHave", "nice_to_have", "bonus")
        )
        technical_skills = skill_tokens(_list("technicalSkills"))
        soft_skills = skill_tokens(_list("softSkills"))

        # Combine technical + soft skills into preferred if no explicit lists.
        if not required_skills and not preferred_skills:
            required_skills = technical_skills
            preferred_skills = soft_skills
        else:
            required_skills = dedupe(required_skills + technical_skills)
            preferred_skills = dedupe(preferred_skills + soft_skills + technical_skills)

        # Fallback: scan all array values for anything that looks like skill lists.
        if not required_skills and not preferred_skills:
            for key, val in data.items():
                if isinstance(val, list) and all(isinstance(s, str) for s in val):
                    skills = skill_tokens(val)
                    if skills:
                        # First array of strings found becomes required skills.
                        if not required_skills:
                            required_skills = skills
                        elif not preferred_skills:
                            preferred_skills = skills
                        break

        return {
            "title": _str("title", "position", "jobTitle", "role", "job_title") or "",
            "required_skills": required_skills,
            "preferred_skills": preferred_skills,
            "min_years": _float("min_years", "minYears", "experience", "years", "yearsNeeded", "years_needed", "minExperience"),
            "education": _str("education", "educationLevel", "degree"),
            "certifications": _list("certifications", "certs"),
            "responsibilities": _list("responsibilities", "duties", "whatYouWillDo"),
        }
