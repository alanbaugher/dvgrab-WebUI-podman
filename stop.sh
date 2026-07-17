#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands curl podman python3 systemctl
stop_service
log "Service stopped"
