#!/usr/bin/env bash
set -euo pipefail

# Run the Flutter test suite.
#   ./run_script.sh test [flutter test args...]

if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found on PATH." >&2
    exit 1
fi

flutter test "$@"
