#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Shared configuration
###############################################################################

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$BASE_DIR/config.env"

[[ -f "$CONFIG_FILE" ]] || {
    printf 'ERROR: Missing configuration file: %s\n' "$CONFIG_FILE" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$CONFIG_FILE"

APP_DIR="${APP_DIR:-$BASE_DIR/app}"
STATE_DIR="${STATE_DIR:-$BASE_DIR/state}"
BUILD_STATE_FILE="${BUILD_STATE_FILE:-$STATE_DIR/build-state.sha256}"

QUADLET_SOURCE_DIR="${QUADLET_SOURCE_DIR:-$BASE_DIR/systemd}"
QUADLET_SOURCE="${QUADLET_SOURCE:-$QUADLET_SOURCE_DIR/dvgrab-webui.container}"
QUADLET_DIR="${QUADLET_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd}"
QUADLET_FILE="${QUADLET_FILE:-$QUADLET_DIR/dvgrab-webui.container}"
QUADLET_BACKUP_DIR="${QUADLET_BACKUP_DIR:-$BASE_DIR/archive/quadlet-backups}"

SERVICE_NAME="${SERVICE_NAME:-dvgrab-webui.service}"
STARTUP_WAIT_SECONDS="${STARTUP_WAIT_SECONDS:-20}"
STOP_WAIT_SECONDS="${STOP_WAIT_SECONDS:-20}"

BUILD_CHANGED=false
QUADLET_CHANGED=false

###############################################################################
# Output and errors
###############################################################################

log() {
    printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

ok() {
    printf '\033[1;32m✓\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
    exit 1
}

on_error() {
    local status=$?
    local line="${1:-unknown}"
    printf 'ERROR: command failed at line %s with status %s\n' "$line" "$status" >&2
    exit "$status"
}

trap 'on_error "$LINENO"' ERR

###############################################################################
# General helpers
###############################################################################

require_non_root() {
    [[ $EUID -ne 0 ]] ||
        die "Run this command as the normal appliance user, without sudo."
}

require_commands() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 ||
            die "Missing required command: $command_name"
    done
}

check_rootless_podman() {
    [[ "$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null || true)" == "true" ]] ||
        die "Podman is not running rootless for $(id -un)."
}

host_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

webui_url() {
    local address
    address="$(host_ip)"
    printf 'http://%s:%s\n' "${address:-127.0.0.1}" "$WEB_PORT"
}

json_value() {
    local json="$1"
    local key="$2"

    python3 -c '
import json
import sys

key = sys.argv[1]
raw = sys.argv[2]

try:
    value = json.loads(raw)

    for part in key.split("."):
        value = value[part]

    if isinstance(value, bool):
        print(str(value).lower())
    elif value is None:
        print("")
    else:
        print(value)
except (json.JSONDecodeError, KeyError, TypeError, IndexError):
    print("")
' "$key" "$json"
}

###############################################################################
# API helpers
###############################################################################

api_get() {
    local endpoint="$1"
    curl --fail --silent --show-error \
        "http://127.0.0.1:${WEB_PORT}${endpoint}"
}

api_post() {
    local endpoint="$1"
    curl --fail --silent --show-error \
        --request POST \
        "http://127.0.0.1:${WEB_PORT}${endpoint}"
}

api_status()   { api_get "/api/status"; }
api_device()   { api_get "/api/device"; }
api_profiles() { api_get "/api/profiles"; }
api_version()  { api_get "/api/version"; }
api_stop()     { api_post "/api/stop"; }

###############################################################################
# Source and image management
###############################################################################

ensure_repo() {
    mkdir -p "$STATE_DIR"

    [[ -f "$APP_DIR/app.py" ]] && return 0

    [[ ! -e "$APP_DIR" || -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]] ||
        die "$APP_DIR exists but does not contain app.py."

    require_commands git
    log "Cloning upstream dvgrab-WebUI into $APP_DIR"
    git clone "$REPO_URL" "$APP_DIR"
}

build_input_files() {
    local path

    for path in \
        "$APP_DIR/Dockerfile" \
        "$APP_DIR/app.py"; do
        [[ -f "$path" ]] && printf '%s\0' "$path"
    done

    if [[ -d "$APP_DIR/templates" ]]; then
        find "$APP_DIR/templates" \
            -type f \
            \( -name '*.html' -o -name '*.jinja' -o -name '*.jinja2' \) \
            ! -name '*.original' \
            ! -name '*.before*' \
            ! -path '*/__pycache__/*' \
            -print0
    fi

    if [[ -d "$APP_DIR/static" ]]; then
        find "$APP_DIR/static" \
            -type f \
            \( -name '*.css' -o -name '*.js' -o -name '*.json' -o -name '*.svg' \
               -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) \
            ! -name '*.original' \
            ! -name '*.before*' \
            ! -path '*/__pycache__/*' \
            -print0
    fi
}

calculate_build_state() {
    local file
    local relative

    while IFS= read -r -d '' file; do
        relative="${file#"$APP_DIR"/}"
        printf '%s\0' "$relative"
        sha256sum "$file" | awk '{printf "%s\0", $1}'
    done < <(build_input_files | sort -z) |
        sha256sum |
        awk '{print $1}'
}

image_exists() {
    podman image exists "$IMAGE_NAME"
}

saved_build_state() {
    [[ -f "$BUILD_STATE_FILE" ]] && cat "$BUILD_STATE_FILE"
}

build_needed() {
    image_exists || return 0
    [[ -f "$BUILD_STATE_FILE" ]] || return 0
    [[ "$(calculate_build_state)" != "$(saved_build_state)" ]]
}

build_image() {
    local force="${FORCE:-false}"

    ensure_repo
    mkdir -p "$STATE_DIR"
    BUILD_CHANGED=false

    if [[ "$force" == "true" ]] || build_needed; then
        log "Building $IMAGE_NAME"
        podman build --pull=missing --tag "$IMAGE_NAME" "$APP_DIR"
        calculate_build_state >"$BUILD_STATE_FILE"
        BUILD_CHANGED=true
    else
        log "Image is current; skipping build"
    fi
}

image_current() {
    image_exists &&
        [[ -f "$BUILD_STATE_FILE" ]] &&
        [[ "$(calculate_build_state)" == "$(saved_build_state)" ]]
}

###############################################################################
# Storage and FireWire
###############################################################################

storage_mounted() {
    mountpoint -q "$NFS_MOUNT"
}

storage_writable() {
    local test_file="$CAPTURE_DIR/.dvgrab-webui-write-test.$$"

    mkdir -p "$CAPTURE_DIR" || return 1
    : >"$test_file" || return 1
    rm -f -- "$test_file"
}

check_storage() {
    storage_mounted || die "$NFS_MOUNT is not mounted."
    findmnt -T "$CAPTURE_DIR" >/dev/null ||
        die "Unable to inspect the filesystem containing $CAPTURE_DIR."
    storage_writable ||
        die "$(id -un) cannot write to $CAPTURE_DIR."
}

firewire_card_present() { [[ -e /dev/fw0 ]]; }
camera_present() { [[ -e /dev/fw1 ]]; }

check_firewire() {
    firewire_card_present ||
        die "/dev/fw0 is missing. Verify the FireWire card and firewire_ohci driver."

    if ! camera_present; then
        warn "/dev/fw1 is missing. Power on the camcorder in VTR/PLAYER mode."
        return 1
    fi
}

show_storage_verbose() {
    log "NFS mount status"
    findmnt "$NFS_MOUNT" || true

    log "NFS capacity"
    df -h "$NFS_MOUNT" || true

    log "Existing Digital8 files"
    if command -v tree >/dev/null 2>&1; then
        tree -a --dirsfirst "$NFS_MOUNT"
    else
        find "$NFS_MOUNT" -mindepth 1 -printf '%y %p\n' | sort
    fi
}

show_firewire_verbose() {
    log "FireWire status"
    ls -l /dev/fw* 2>/dev/null || printf 'No FireWire device nodes found.\n'
    if command -v lspci >/dev/null 2>&1; then
        lspci -nn | grep -i firewire || true
    fi
}

###############################################################################
# Quadlet management
###############################################################################

render_quadlet() {
    cat <<EOF
[Unit]
Description=dvgrab-WebUI
RequiresMountsFor=$CAPTURE_DIR
After=network-online.target
Wants=network-online.target

[Container]
Image=$IMAGE_NAME
ContainerName=$CONTAINER_NAME
PublishPort=$WEB_PORT:5000
Volume=$CAPTURE_DIR:/captures:rw
Pull=never
PodmanArgs=--device=/dev/fw0
PodmanArgs=--device=/dev/fw1

[Service]
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
}

write_quadlet_template() {
    mkdir -p "$QUADLET_SOURCE_DIR"
    render_quadlet >"$QUADLET_SOURCE"
}

backup_quadlet_if_changed() {
    local timestamp
    local backup_file

    [[ -f "$QUADLET_FILE" ]] || return 0
    cmp -s "$QUADLET_SOURCE" "$QUADLET_FILE" && return 0

    mkdir -p "$QUADLET_BACKUP_DIR"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_file="$QUADLET_BACKUP_DIR/dvgrab-webui.container.$timestamp"
    cp -a -- "$QUADLET_FILE" "$backup_file"
    printf 'Backup: %s\n' "$backup_file"
}

install_quadlet() {
    write_quadlet_template
    mkdir -p "$QUADLET_DIR"
    QUADLET_CHANGED=false

    if cmp -s "$QUADLET_SOURCE" "$QUADLET_FILE" 2>/dev/null; then
        log "Quadlet definition is current"
    else
        backup_quadlet_if_changed
        log "Installing Quadlet definition"
        install -m 0644 "$QUADLET_SOURCE" "$QUADLET_FILE"
        QUADLET_CHANGED=true
    fi

    systemctl --user daemon-reload
    service_exists ||
        die "Quadlet did not generate $SERVICE_NAME."
}

remove_quadlet() {
    local timestamp
    local backup_file

    [[ -f "$QUADLET_FILE" ]] || {
        warn "Quadlet is already absent: $QUADLET_FILE"
        return 0
    }

    mkdir -p "$QUADLET_BACKUP_DIR"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_file="$QUADLET_BACKUP_DIR/dvgrab-webui.container.removed.$timestamp"

    cp -a -- "$QUADLET_FILE" "$backup_file"
    rm -f -- "$QUADLET_FILE"
    systemctl --user daemon-reload
    systemctl --user reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

    printf 'Removed Quadlet. Backup: %s\n' "$backup_file"
}

service_exists() {
    systemctl --user cat "$SERVICE_NAME" >/dev/null 2>&1
}

service_active() {
    systemctl --user is-active --quiet "$SERVICE_NAME"
}

###############################################################################
# Service lifecycle
###############################################################################

wait_for_webui() {
    local attempts=$((STARTUP_WAIT_SECONDS * 2))

    log "Waiting up to ${STARTUP_WAIT_SECONDS}s for WebUI readiness"
    while ((attempts > 0)); do
        if api_status >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
        ((attempts -= 1))
    done
    return 1
}

capture_running() {
    local status
    status="$(api_status 2>/dev/null || true)"
    [[ "$(json_value "$status" running)" == "true" ]]
}

request_capture_stop() {
    local attempts=$((STOP_WAIT_SECONDS * 2))

    capture_running || return 0
    warn "A DV capture is active. Requesting a clean stop."
    api_stop >/dev/null || return 1

    while ((attempts > 0)); do
        capture_running || return 0
        sleep 0.5
        ((attempts -= 1))
    done
    return 1
}

start_service() {
    service_exists ||
        die "$SERVICE_NAME is not installed. Run ./install.sh first."

    systemctl --user start "$SERVICE_NAME"
    wait_for_webui || {
        systemctl --user status --no-pager -l "$SERVICE_NAME" || true
        journalctl --user -u "$SERVICE_NAME" -n 80 --no-pager || true
        die "WebUI did not become ready."
    }
    log "WebUI ready at $(webui_url)"
}

stop_service() {
    if capture_running; then
        request_capture_stop ||
            warn "Capture did not report stopped before service shutdown."
    fi

    if service_exists; then
        systemctl --user stop "$SERVICE_NAME"
    else
        warn "$SERVICE_NAME is not installed."
    fi
}

restart_service() {
    service_exists ||
        die "$SERVICE_NAME is not installed. Run ./install.sh first."

    if capture_running; then
        request_capture_stop ||
            warn "Capture did not report stopped before restart."
    fi

    systemctl --user restart "$SERVICE_NAME"
    wait_for_webui || {
        systemctl --user status --no-pager -l "$SERVICE_NAME" || true
        journalctl --user -u "$SERVICE_NAME" -n 80 --no-pager || true
        die "WebUI did not become ready after restart."
    }
    log "WebUI restart complete"
}

remove_container_if_present() {
    podman container exists "$CONTAINER_NAME" || return 0
    podman rm --force --time "$STOP_WAIT_SECONDS" "$CONTAINER_NAME" || true
}

###############################################################################
# Compact and verbose status
###############################################################################

status_word() {
    [[ "$1" == "true" ]] && printf 'OK' || printf 'NOT OK'
}

show_status_compact() {
    local service_ok=false
    local storage_ok=false
    local camera_ok=false
    local card_ok=false
    local image_ok=false
    local api_ok=false
    local version_json=""
    local device_json=""
    local status_json=""
    local version=""
    local camera=""
    local capture="unknown"

    service_active && service_ok=true
    storage_mounted && storage_writable && storage_ok=true
    firewire_card_present && card_ok=true
    camera_present && camera_ok=true
    image_current && image_ok=true

    if [[ "$service_ok" == true ]]; then
        status_json="$(api_status 2>/dev/null || true)"
        version_json="$(api_version 2>/dev/null || true)"
        device_json="$(api_device 2>/dev/null || true)"
        [[ -n "$status_json" ]] && api_ok=true
    fi

    version="$(json_value "$version_json" version)"
    camera="$(json_value "$device_json" model)"
    capture="$(json_value "$status_json" running)"
    [[ "$capture" == "true" ]] && capture="RUNNING" || capture="idle"

    cat <<EOF
Digital8 Capture Appliance
--------------------------
Service:      $(status_word "$service_ok")
WebUI/API:    $(status_word "$api_ok")
Version:      ${version:-unknown}
Capture:      $capture
Camera:       ${camera:-not detected}
FireWire:     $(status_word "$card_ok")
Storage/NFS:  $(status_word "$storage_ok")
Image:        $([[ "$image_ok" == true ]] && echo current || echo rebuild needed)
WebUI:        $(webui_url)

Use "./status.sh --verbose" for full diagnostics.
EOF
}

show_status_verbose() {
    show_storage_verbose
    show_firewire_verbose

    log "Quadlet service status"
    if service_exists; then
        systemctl --user status --no-pager -l "$SERVICE_NAME" || true
    else
        printf '%s is not installed.\n' "$SERVICE_NAME"
    fi

    log "Container status"
    podman ps -a --filter "name=${CONTAINER_NAME}"
    podman port "$CONTAINER_NAME" 2>/dev/null || true

    log "Image status"
    podman image inspect "$IMAGE_NAME" \
        --format 'ID={{.Id}} Created={{.Created}} Size={{.Size}}' \
        2>/dev/null || printf 'Image not built\n'

    log "Build state"
    printf 'Saved:   %s\n' "$(saved_build_state)"
    printf 'Current: %s\n' "$(calculate_build_state)"
    printf 'State:   %s\n' "$([[ "$(saved_build_state)" == "$(calculate_build_state)" ]] && echo current || echo rebuild-needed)"

    log "WebUI API"
    printf 'Version:  %s\n' "$(api_version 2>/dev/null || true)"
    printf 'Status:   %s\n' "$(api_status 2>/dev/null || true)"
    printf 'Device:   %s\n' "$(api_device 2>/dev/null || true)"
    printf 'Profiles: %s\n' "$(api_profiles 2>/dev/null || true)"
}
