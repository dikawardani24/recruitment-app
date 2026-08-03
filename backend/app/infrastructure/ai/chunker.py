from __future__ import annotations

from uuid import uuid4

from app.core.enums import Section
from app.domain.entities import Candidate, CandidateProfile, SemanticChunk


class SemanticChunker:
    """Builds semantically homogeneous chunks from a structured profile (doc 10 §2.1)."""

    def chunk(self, candidate: Candidate, resume_id) -> list[SemanticChunk]:
        profile: CandidateProfile = candidate.profile
        chunks: list[SemanticChunk] = []

        if profile.summary:
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.SUMMARY,
                    text=f"Summary — {profile.summary}",
                    version=0,
                    embedding_model="",
                )
            )

        if profile.skills:
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.SKILLS,
                    text="Skills — " + ", ".join(profile.skills),
                    version=0,
                    embedding_model="",
                )
            )

        for e in profile.experience:
            period = f"{e.start_date or '?'} to {e.end_date or 'Present'}"
            lines = "\n".join(f"• {r}" for r in e.responsibilities) or "• (no details listed)"
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.EXPERIENCE,
                    text=f"Experience — {e.company}\n{e.position} ({period})\n{lines}",
                    version=0,
                    embedding_model="",
                )
            )

        for p in profile.projects:
            highlights = "\n".join(f"• {h}" for h in p.highlights) or ""
            text = f"Project — {p.name}\n{p.description}\n{highlights}".strip()
            if p.url:
                text += f"\nURL: {p.url}"
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.PROJECTS,
                    text=text,
                    version=0,
                    embedding_model="",
                )
            )

        if profile.certifications:
            certs = ", ".join(c.name for c in profile.certifications)
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.CERTIFICATIONS,
                    text=f"Certifications — {certs}",
                    version=0,
                    embedding_model="",
                )
            )

        if profile.education:
            lines = "\n".join(f"• {e.degree} {e.field or ''} @ {e.institution}".strip() for e in profile.education)
            chunks.append(
                SemanticChunk(
                    id=uuid4(),
                    candidate_id=candidate.id,
                    candidate_name=candidate.name,
                    resume_id=resume_id,
                    section=Section.EDUCATION,
                    text=f"Education\n{lines}",
                    version=0,
                    embedding_model="",
                )
            )

        return chunks
