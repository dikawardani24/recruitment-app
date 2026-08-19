#!/usr/bin/env bash
set -euo pipefail

# Shared helper for choosing the backend API base URL when running or building
# the Flutter frontend. Sourced by run.sh, build_apk.sh, and build_web.sh.
#
# Resolution priority:
#   1. --api-base <url> (or --api-base=<url>) CLI flag
#   2. API_BASE_URL environment variable
#   3. Interactive menu (when stdin is a TTY)
#   4. First known backend

# Known backends, shown in menu order.
API_BASE_OPTIONS=(
  "Local backend — http://localhost:8000/api"
  "Android emulator — http://10.0.2.2:8000/api"
  "Deployed (Render) — https://recruitment-app-z4kg.onrender.com/api"
)
API_BASE_URLS=(
  "http://localhost:8000/api"
  "http://10.0.2.2:8000/api"
  "https://recruitment-app-z4kg.onrender.com/api"
)

# Parses the argument list, strips any --api-base flag, and stores the results
# in the caller's shell: API_BASE_FLAG (the URL from the flag) and
# API_BASE_ARGS (the remaining arguments). Must be called directly, never in a
# command substitution / pipeline subshell, or the results would be lost.
extract_api_base_flag() {
  API_BASE_FLAG=""
  API_BASE_ARGS=()
  local skip=0
  while (($#)); do
    if ((skip)); then
      skip=0; shift; continue
    fi
    case "$1" in
      --api-base=*)
        API_BASE_FLAG="${1#--api-base=}"
        ;;
      --api-base)
        if (($# >= 2)); then
          API_BASE_FLAG="$2"; skip=1
        else
          echo "--api-base requires a value." >&2
          return 1
        fi
        ;;
      *)
        API_BASE_ARGS+=("$1")
        ;;
    esac
    shift
  done
}

# Prompts the user to pick a backend (used when stdin is a TTY).
# Display goes to stderr so it stays visible even when stdout is captured
# by a command substitution; only the chosen URL goes to stdout.
prompt_api_base() {
  local n="${#API_BASE_OPTIONS[@]}"
  echo "" >&2
  echo "Select API base URL:" >&2
  local i
  for i in "${!API_BASE_OPTIONS[@]}"; do
    printf '  %d. %s\n' "$((i + 1))" "${API_BASE_OPTIONS[$i]}" >&2
  done
  printf '  %d. Custom URL\n' "$((n + 1))" >&2
  local choice url
  read -rp "Pick [1-$((n + 1))]: " choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= n)); then
    url="${API_BASE_URLS[$((choice - 1))]}"
  elif [[ "$choice" == "$((n + 1))" ]]; then
    read -rp "Enter base URL: " url
  else
    echo "Invalid choice, using default." >&2
    url="${API_BASE_URLS[0]}"
  fi
  printf '%s' "$url"
}

# Resolves and prints the API base URL to use.
resolve_api_base() {
  if [[ -n "${API_BASE_FLAG:-}" ]]; then
    printf '%s' "$API_BASE_FLAG"
    return 0
  fi
  if [[ -n "${API_BASE_URL:-}" ]]; then
    printf '%s' "$API_BASE_URL"
    return 0
  fi
  if [[ -t 0 ]]; then
    prompt_api_base
    return 0
  fi
  printf '%s' "${API_BASE_URLS[0]}"
}

# Prints the --dart-define argument for the resolved base URL.
api_base_dart_define() {
  local base
  base="$(resolve_api_base)" || return 1
  printf '%s' "--dart-define=API_BASE_URL=$base"
}