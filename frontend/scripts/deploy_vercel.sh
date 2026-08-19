#!/usr/bin/env bash
set -euo pipefail

# Build the Flutter web release and deploy the static bundle to Vercel.
#   ./run_script.sh deploy_vercel [flags...]
#
# Flags:
#   --api-base <url>   backend API base URL baked into the build. Defaults to
#                      the deployed backend (production), so a plain
#                      `./run_script.sh deploy_vercel` is all you need.
#   --skip-build       deploy the existing frontend/build/web without rebuilding
#   everything else    passed through to `vercel --prod`, e.g. --token <token>,
#                      --yes, or --project <name>
#
# Flutter is not available in Vercel's build image, so the web bundle is built
# locally and the static output directory is deployed. First run links or
# creates the Vercel project interactively (or pass --token for CI).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/_lib_api_base.sh"

if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found on PATH." >&2
    exit 1
fi

# Production default: point the deployed app at the deployed backend.
: "${API_BASE_URL:=https://recruitment-app-z4kg.onrender.com/api}"

SKIP_BUILD=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=1 ;;
        *) ARGS+=("$arg") ;;
    esac
done

extract_api_base_flag "${ARGS[@]}"

if ((SKIP_BUILD)); then
    echo "Skipping build (--skip-build); deploying frontend/build/web as-is."
else
    echo ">>> Building web release ($(api_base_dart_define))"
    flutter build web --release "$(api_base_dart_define)"
fi

echo ">>> Deploying frontend/build/web to Vercel (--prod)"
cd "$SCRIPT_DIR/../build/web"
npx --yes vercel --prod --yes "${API_BASE_ARGS[@]}"