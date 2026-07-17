#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands curl find findmnt mountpoint podman python3 sha256sum sort systemctl awk

case "${1:-}" in
    "") show_status_compact ;;
    --verbose|-v) show_status_verbose ;;
    -h|--help)
        printf 'Usage: ./status.sh [--verbose]\n'
        ;;
    *) die "Unknown option: $1" ;;
esac
