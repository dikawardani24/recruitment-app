#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ── load env ────────────────────────────────────────────────────────────────
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env"
    set +a
fi

# ── helpers ─────────────────────────────────────────────────────────────────
script_description() {
    grep '^#' "$1" | grep -v '^#!' | sed 's/^# *//' | head -1
}

print_menu() {
    local project="$1" label="$2"
    echo ""
    echo "=== $label — AVAILABLE COMMANDS ==="
    echo ""
    local idx=1
    local dir="$SCRIPT_DIR/$project"
    for file in "$dir"/*.sh; do
        [[ -f "$file" ]] || continue
        local name desc
        name="$(basename "${file%.sh}")"
        desc="$(script_description "$file")"
        printf '  %d. %-12s  %s\n' "$idx" "$name" "$desc"
        ((idx++))
    done
    echo ""
}

get_script_by_index() {
    local project="$1" idx="$2"
    local dir="$SCRIPT_DIR/$project"
    local count=0
    for file in "$dir"/*.sh; do
        [[ -f "$file" ]] || continue
        ((count++))
        if [[ "$count" -eq "$idx" ]]; then
            basename "${file%.sh}"
            return 0
        fi
    done
    return 1
}

script_count() {
    local dir="$SCRIPT_DIR/$1"
    ls "$dir"/*.sh 2>/dev/null | wc -l | tr -d ' '
}

run_script() {
    local project="$1" script="$2"
    shift 2
    cd "$ROOT_DIR/$project"
    bash "$SCRIPT_DIR/$project/$script.sh" "$@"
}

# ── interactive menu ────────────────────────────────────────────────────────
menu() {
    local project="" label="" count="" choice="" script=""

    echo ""
    echo "=== AVAILABLE PROJECTS ==="
    echo ""
    echo "  1. Backend"
    echo ""
    echo "  2. Frontend"
    echo ""
    read -rp "Pick a project [1-2, q to quit]: " choice

    case "$choice" in
        1) project="backend"; label="Backend" ;;
        2) project="frontend"; label="Frontend" ;;
        [qQ]) echo "Quitting." >&2; exit 0 ;;
        *) echo "Invalid choice." >&2; menu; return ;;
    esac

    count="$(script_count "$project")"
    if [[ "$count" -eq 0 ]]; then
        echo "No scripts found for $label." >&2
        return
    fi

    print_menu "$project" "$label"
    read -rp "Pick a command [1-${count}, b for back, q to quit]: " choice

    case "$choice" in
        [qQ]) echo "Quitting." >&2; exit 0 ;;
        b|B) menu; return ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
                script="$(get_script_by_index "$project" "$choice")"
                echo ""
                echo ">>> Running: $project/$script"
                echo ""
                run_script "$project" "$script"
            else
                echo "Invalid choice." >&2
                print_menu "$project" "$label"
                read -rp "Pick a command [1-${count}, q to quit]: " choice
                case "$choice" in
                    [qQ]) exit 0 ;;
                    *) script="$(get_script_by_index "$project" "$choice")" && run_script "$project" "$script" ;;
                esac
            fi
            ;;
    esac
}

# ── main ────────────────────────────────────────────────────────────────────
# Non-interactive: run script directly.
if [[ $# -gt 0 ]]; then
    SCRIPT_NAME="$1"; shift

    if [[ "$SCRIPT_NAME" == */* ]]; then
        PROJECT="${SCRIPT_NAME%%/*}"
        SCRIPT_NAME="${SCRIPT_NAME#*/}"
    else
        RESOLVED=""
        for project in backend frontend; do
            if [[ -f "$SCRIPT_DIR/$project/$SCRIPT_NAME.sh" ]]; then
                RESOLVED="$project"
                break
            fi
        done
        if [[ -z "$RESOLVED" ]]; then
            echo "Unknown script '$SCRIPT_NAME'." >&2
            echo "Run without arguments to open the interactive menu." >&2
            exit 1
        fi
        PROJECT="$RESOLVED"
    fi

    if [[ ! -f "$SCRIPT_DIR/$PROJECT/$SCRIPT_NAME.sh" ]]; then
        echo "Unknown script '$PROJECT/$SCRIPT_NAME'." >&2
        exit 1
    fi

    cd "$ROOT_DIR/$PROJECT"
    bash "$SCRIPT_DIR/$PROJECT/$SCRIPT_NAME.sh" "$@"
    exit 0
fi

# Interactive menu.
menu
