#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands df find findmnt mountpoint
check_storage
show_storage_verbose
