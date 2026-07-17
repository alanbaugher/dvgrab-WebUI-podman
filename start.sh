#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands curl find findmnt mountpoint podman python3 sha256sum sort systemctl awk
check_rootless_podman
check_storage
check_firewire
build_image
install_quadlet
start_service
