#!/usr/bin/env bash
set -euo pipefail

# Launch the Flutter frontend.
#   ./run_script.sh run [flutter run args...]
#
# Pass device/target args through, e.g.: ./run_script.sh run -d chrome

if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found on PATH." >&2
    exit 1
fi

flutter run "$@"
