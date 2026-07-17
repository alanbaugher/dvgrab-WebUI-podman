#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

APPLY=false

usage() {
    cat <<'EOF'
Usage: ./cleanup.sh [--apply]

Without --apply, show cleanup candidates only.

--apply:
  Remove generated Python cache and the accidental app/templates/o tree.
  Move active-tree backup files into a timestamped archive directory.

The active app.py, Dockerfile, index.html, LICENSE, and README files are kept.
EOF
}

while (($#)); do
    case "$1" in
        --apply) APPLY=true ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

require_non_root
require_commands find mkdir mv rm

timestamp="$(date +%Y%m%d-%H%M%S)"
destination="$BASE_DIR/archive/cleanup-$timestamp"

mapfile -d '' candidates < <(
    find "$APP_DIR" -maxdepth 3 \
        \( -type d -name '__pycache__' -print0 -prune \) -o \
        \( -type f -name '*.pyc' -print0 \) -o \
        \( -type f -name '*.original' -print0 \) -o \
        \( -type f -name '*.before*' -print0 \)
)

if [[ -d "$APP_DIR/templates/o" ]]; then
    candidates+=("$APP_DIR/templates/o")
fi

if ((${#candidates[@]} == 0)); then
    printf 'No cleanup candidates found.\n'
    exit 0
fi

printf 'Cleanup candidates:\n'
printf '  %s\n' "${candidates[@]}"

if [[ "$APPLY" != true ]]; then
    printf '\nDry run only. Use "./cleanup.sh --apply" to proceed.\n'
    exit 0
fi

mkdir -p "$destination"

for candidate in "${candidates[@]}"; do
    [[ -e "$candidate" ]] || continue

    case "$candidate" in
        */__pycache__|*.pyc|*/templates/o)
            rm -rf -- "$candidate"
            ;;
        *)
            relative="${candidate#"$BASE_DIR"/}"
            mkdir -p "$destination/$(dirname "$relative")"
            mv -- "$candidate" "$destination/$relative"
            ;;
    esac
done

printf 'Cleanup completed.\n'
printf 'Archived backups: %s\n' "$destination"
