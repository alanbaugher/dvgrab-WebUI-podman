#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands curl findmnt mountpoint podman python3 systemctl
check_rootless_podman
check_storage
check_firewire
restart_service
