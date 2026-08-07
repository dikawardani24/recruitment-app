#!/usr/bin/env bash
set -euo pipefail

# Seed the DB with a sample job (idempotent). Runs an inline Python snippet
# through the app's own tooling, showing how bash scripts can reuse the app.
#   ./run_script.sh seed [job-id]

JOB_ID="${1:-sample-job}"
DB_PATH="${ATS_DB__PATH:-./data/ats.db}"
DB_PATH="${DB_PATH#file:}"

PY=.venv/bin/python
if [[ ! -x "$PY" ]]; then
    echo "No .venv found; create it first:" >&2
    exit 1
fi

if "$PY" -c 'import sqlite3,sys' 2>/dev/null; then
    EXISTS="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM jobs WHERE id='$JOB_ID';" 2>/dev/null || echo 0)"
    if [[ "$EXISTS" != "0" ]]; then
        echo "Job '$JOB_ID' already exists, skipping."
        exit 0
    fi
fi

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
"$PY" - "$JOB_ID" "$NOW" <<'EOF'
import json, sqlite3, sys, os

job_id, now = sys.argv[1], sys.argv[2]
db_path = os.getenv("ATS_DB__PATH", "./data/ats.db").removeprefix("file:")
os.makedirs(os.path.dirname(db_path), exist_ok=True)

requirements = [
    {"text": "Python", "type": "skill", "required": True},
    {"text": "Docker", "type": "skill", "required": True},
    {"text": "AWS", "type": "skill", "required": True},
    {"text": "5+ years of experience", "type": "experience", "required": True},
]

with sqlite3.connect(db_path) as conn:
    if conn.execute("SELECT COUNT(*) FROM jobs WHERE id = ?", (job_id,)).fetchone()[0]:
        print(f"Job {job_id!r} already exists, skipping.")
        sys.exit(0)
    conn.execute(
        """
        INSERT INTO jobs (id, title, description, requirements, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            job_id,
            "Senior Backend Engineer",
            "Design and operate highly available backend services.",
            json.dumps(requirements),
            "draft",
            now,
            now,
        ),
    )
    conn.commit()

print(f"Seeded job {job_id!r}.")
EOF
