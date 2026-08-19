#!/usr/bin/env bash
set -euo pipefail

# Build release APKs of the Flutter frontend, split per ABI.
#   ./run_script.sh build_apk [flutter build apk args...]
#
# Choose the backend API base URL with --api-base <url>, or pick from an
# interactive menu when none is given.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib_api_base.sh"

if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found on PATH." >&2
    exit 1
fi

extract_api_base_flag "$@"

flutter build apk --release --split-per-abi "$(api_base_dart_define)" "${API_BASE_ARGS[@]}"
