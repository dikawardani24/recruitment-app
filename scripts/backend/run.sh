#!/usr/bin/env bash
set -euo pipefail

# Start the backend server (uvicorn) with auto-reload.
#   ./run_script.sh run [--port 8000]

PORT="${ATS_PORT:-8000}"
HOST="${ATS_HOST:-127.0.0.1}"
REST_ARGS=()

# Extract --port/--host if provided; keep the rest.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        *)
            REST_ARGS+=("$1")
            shift
            ;;
    esac
done

PY=.venv/bin/python
if [[ ! -x "$PY" ]]; then
    echo "No .venv found; create it first:" >&2
    echo "  python3 -m venv .venv && .venv/bin/pip install -r requirements.txt" >&2
    exit 1
fi

if [[ ${#REST_ARGS[@]} -gt 0 ]]; then
    exec "$PY" -m uvicorn app.main:app --reload --host "$HOST" --port "$PORT" "${REST_ARGS[@]}"
else
    exec "$PY" -m uvicorn app.main:app --reload --host "$HOST" --port "$PORT"
fi
