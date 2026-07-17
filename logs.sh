#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands journalctl
journalctl --user -u "$SERVICE_NAME" -f
