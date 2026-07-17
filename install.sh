#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

RESTART=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--restart]

Default:
  Install or refresh the image and Quadlet.
  Start the service if it is stopped.
  Do not interrupt an already-running service.

--restart:
  Restart a running service after installation. A running capture is stopped
  cleanly first.
EOF
}

while (($#)); do
    case "$1" in
        --restart) RESTART=true ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

require_non_root
require_commands \
    cmp curl date find findmnt hostname install journalctl mkdir mountpoint \
    podman python3 sha256sum sort systemctl awk
check_rootless_podman

log "Checking capture storage"
check_storage

log "Checking FireWire devices"
camera_ready=true
check_firewire || camera_ready=false

build_image

log "Installing rootless Quadlet"
install_quadlet

if ! service_active; then
    if [[ "$camera_ready" == true ]]; then
        log "Starting stopped service"
        start_service
    else
        warn "Quadlet installed but not started because /dev/fw1 is absent."
    fi
elif [[ "$RESTART" == true ]]; then
    log "Restart requested"
    restart_service
elif [[ "$BUILD_CHANGED" == true || "$QUADLET_CHANGED" == true ]]; then
    warn "Deployment files changed, but the running service was not interrupted."
    warn "Run ./restart.sh after the current capture, or use ./install.sh --restart."
else
    log "Running service is already current; no restart needed"
fi

cat <<EOF

Installed Quadlet:
  $QUADLET_FILE

Project template:
  $QUADLET_SOURCE

Image:
  $IMAGE_NAME

Capture directory:
  $CAPTURE_DIR

Automatic startup is provided by WantedBy=default.target.
For startup without an interactive login:
  sudo loginctl enable-linger $(id -un)

EOF
