#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

require_non_root
require_commands podman sha256sum find sort awk python3
check_rootless_podman
build_image
