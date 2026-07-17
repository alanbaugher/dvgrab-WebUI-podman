#!/usr/bin/env bash
source "$(dirname "$0")/lib/common.sh"

FAILURES=0

pass() { ok "$1"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

require_non_root
require_commands bash curl find findmnt mountpoint podman python3 sha256sum sort systemctl awk

printf 'dvgrab-WebUI validation\n'
printf '%s\n' '-----------------------'

# Syntax and source checks
while IFS= read -r -d '' script; do
    if bash -n "$script"; then
        pass "Shell syntax: ${script#"$BASE_DIR"/}"
    else
        fail "Shell syntax: ${script#"$BASE_DIR"/}"
    fi
done < <(
    find "$BASE_DIR" \
        -maxdepth 2 \
        -type f \
        -name '*.sh' \
        ! -path '*/archive/*' \
        -print0 |
    sort -z
)

if python3 -c 'import ast, pathlib, sys; p = pathlib.Path(sys.argv[1]); ast.parse(p.read_text(encoding="utf-8"), filename=str(p))' "$APP_DIR/app.py"; then
    pass "Python syntax: app/app.py"
else
    fail "Python syntax: app/app.py"
fi

check "Rootless Podman" check_rootless_podman
check "NFS mount present" storage_mounted
check "Capture directory writable" storage_writable
check "FireWire card /dev/fw0" firewire_card_present
check "Camera /dev/fw1" camera_present
check "Container image exists" image_exists
check "Build state is current" image_current
check "Quadlet source exists" test -f "$QUADLET_SOURCE"
check "Installed Quadlet exists" test -f "$QUADLET_FILE"
check "Generated service exists" service_exists
check "Service is running" service_active
check "Status API" api_status
check "Version API" api_version
check "Profiles API" api_profiles
check "Device API" api_device

printf '\n'
if ((FAILURES == 0)); then
    printf '\033[1;32mVALIDATION PASSED\033[0m\n'
    exit 0
fi

printf '\033[1;31mVALIDATION FAILED: %d check(s)\033[0m\n' "$FAILURES"
exit 1
