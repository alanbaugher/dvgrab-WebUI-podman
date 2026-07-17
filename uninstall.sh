#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

REMOVE_QUADLET=false
REMOVE_IMAGE=false
ASSUME_YES=false

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [OPTIONS]

Options:
  --remove-quadlet  Remove the installed Quadlet after backing it up
  --remove-image    Remove the local image
  --yes             Skip confirmation prompts
  -h, --help        Show help

Without options, only the service and any leftover container are stopped.
Captured media, source, image, Quadlet, and NFS storage are preserved.
EOF
}

confirm() {
    local answer
    [[ "$ASSUME_YES" == true ]] && return 0
    read -r -p "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

while (($#)); do
    case "$1" in
        --remove-quadlet) REMOVE_QUADLET=true ;;
        --remove-image) REMOVE_IMAGE=true ;;
        --yes) ASSUME_YES=true ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

require_non_root
require_commands curl podman python3 systemctl

log "Stopping dvgrab-WebUI"
stop_service
remove_container_if_present

if [[ "$REMOVE_QUADLET" == true ]]; then
    confirm "Remove installed Quadlet $QUADLET_FILE?" && remove_quadlet ||
        warn "Quadlet removal cancelled."
else
    printf '\nQuadlet preserved:\n  %s\n' "$QUADLET_FILE"
fi

if [[ "$REMOVE_IMAGE" == true ]]; then
    if image_exists; then
        confirm "Remove image $IMAGE_NAME?" &&
            podman image rm "$IMAGE_NAME" ||
            warn "Image removal cancelled."
    fi
else
    printf '\nImage preserved:\n  %s\n' "$IMAGE_NAME"
fi

cat <<EOF

Captured media was not touched.
The NFS mount was not touched.
The source tree was not touched.

To reinstall:
  ./install.sh

EOF
