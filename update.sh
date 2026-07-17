#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

RESTART=false

while (($#)); do
    case "$1" in
        --restart) RESTART=true ;;
        -h|--help)
            printf 'Usage: ./update.sh [--restart]\n'
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

require_non_root
require_commands curl find git podman python3 sha256sum sort systemctl awk
check_rootless_podman
ensure_repo

log "Updating upstream source"
git -C "$APP_DIR" fetch --all --prune
git -C "$APP_DIR" pull --ff-only

FORCE=true
build_image

if service_active; then
    if [[ "$RESTART" == true ]]; then
        restart_service
    else
        warn "Image updated; running service was not interrupted."
        warn "Run ./restart.sh when ready."
    fi
else
    warn "$SERVICE_NAME is not running; image updated without starting it."
fi
