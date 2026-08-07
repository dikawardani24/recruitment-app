#!/usr/bin/env bash
set -euo pipefail

# Static analysis for the Flutter frontend.
#   ./run_script.sh analyze [flutter analyze args...]

if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found on PATH." >&2
    exit 1
fi

flutter analyze "$@"
