#!/usr/bin/env bash
set -euo pipefail

# Template for one-off backend scripts. Runs from backend/ with env loaded.
#   ./run_script.sh template [extra args...]

echo "Running template script. Extra args: $*"
echo "Working dir: $(pwd)"
echo "DB path: ${ATS_DB__PATH:-./data/ats.db}"
echo "Venv python: $([ -x .venv/bin/python ] && echo yes || echo no)"
