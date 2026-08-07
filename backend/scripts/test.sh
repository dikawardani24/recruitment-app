#!/usr/bin/env bash
set -euo pipefail

# Run the backend's pytest suite.
#   ./run_script.sh test [pytest args...]

PY=.venv/bin/python
if [[ ! -x "$PY" ]]; then
    echo "No .venv found; create it first:" >&2
    echo "  python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
    exit 1
fi

PYTHONPATH=. "$PY" -m pytest tests "$@"
