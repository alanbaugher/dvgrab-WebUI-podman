#!/usr/bin/env bash
#
# capture-tape-via-dvgrab-cmd-line.sh
#
# Unattended Digital8/MiniDV capture workflow:
#   - optional rewind
#   - AVI Type-2 by default, raw DV with --dv
#   - scene splitting
#   - recording-date filenames from dvgrab
#   - ffprobe validation
#   - thumbnails
#   - SHA-256 checksums
#   - JSON manifest
#   - move from incoming/ to completed/
#
# The tape's embedded recording date is best-effort metadata. Some cameras or
# tapes report invalid dates (for example, 2067). Implausible dates are retained
# in the manifest but are not used to name the completed folder.
#

set -Eeuo pipefail

SCRIPT_VERSION="2.0.0"

###############################################################################
# Defaults
###############################################################################

ROOT="${DIGITAL8_ROOT:-/mnt/digital8}"
INCOMING_ROOT="${ROOT}/incoming"
COMPLETED_ROOT="${ROOT}/completed"
FAILED_ROOT="${ROOT}/failed"

PROFILE="archival"
FORMAT="dv2"
EXTENSION="avi"
MAX_RUNTIME="150m"

REWIND=true
AUTOSPLIT=true
VALIDATE=true
THUMBNAILS=true
CHECKSUMS=true
USE_TAPE_DATE_FOLDER=true

SESSION_NAME=""
OVERWRITE=false

###############################################################################
# Helpers
###############################################################################

usage() {
    cat <<'EOF'
Usage:
  capture-tape-via-dvgrab-cmd-line.sh [SESSION_NAME] [OPTIONS]

Examples:
  ./capture-tape-via-dvgrab-cmd-line.sh TAPE0001
  ./capture-tape-via-dvgrab-cmd-line.sh "Family Christmas 1999"
  ./capture-tape-via-dvgrab-cmd-line.sh TAPE0002 --dv
  ./capture-tape-via-dvgrab-cmd-line.sh TAPE0003 --profile quick
  ./capture-tape-via-dvgrab-cmd-line.sh TAPE0004 --no-rewind
  ./capture-tape-via-dvgrab-cmd-line.sh TAPE0005 --max-runtime 90m

Profiles:
  archival   AVI Type-2, rewind, autosplit, validate, thumbnails, SHA-256
             This is the default.

  raw        Raw .dv, rewind, autosplit, validate, thumbnails, SHA-256

  quick      AVI Type-2, rewind, no autosplit, validation only

Options:
  --profile NAME          archival, raw, or quick
  --avi                   Capture AVI Type-2; default
  --dv                    Capture raw DV
  --rewind                Rewind before capture; default
  --no-rewind             Start capture at the current tape position
  --autosplit             Split on recording/scene boundaries; default
  --no-autosplit          Capture as one continuous file
  --validate              Run ffprobe validation; default
  --no-validate           Skip ffprobe validation
  --thumbnails            Generate thumbnails; default for archival/raw
  --no-thumbnails         Skip thumbnails
  --checksums             Generate SHA-256 sidecars; default for archival/raw
  --no-checksums          Skip SHA-256 sidecars
  --date-folder           Prefix completed folder with earliest valid tape date
  --no-date-folder        Do not use the tape date in the completed folder name
  --max-runtime DURATION  Safety timeout accepted by GNU timeout; default 150m
  --overwrite             Remove an existing incoming session directory
  -h, --help              Show this help

Folder naming:
  The supplied SESSION_NAME is sanitized for filesystem use.

  Example:
      "Family Christmas 1999" -> Family_Christmas_1999

  When a plausible recording date is available and --date-folder is enabled:
      1999-12-25_Family_Christmas_1999

Recording dates:
  dvgrab reads the recording timestamp embedded in the DV stream and uses it
  in filenames with --timestamp. Invalid or implausible timestamps are kept in
  the manifest but are not trusted for folder naming.
EOF
}

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command not found: $1"
}

sanitize_name() {
    local value="$1"

    # Replace whitespace with underscores, remove unsafe characters, collapse
    # repeated separators, and trim leading/trailing separators.
    value="${value// /_}"
    value="$(printf '%s' "$value" |
        tr -cd 'A-Za-z0-9._-' |
        sed -E 's/[_-]+/_/g; s/^[._-]+//; s/[._-]+$//')"

    [[ -n "$value" ]] || die "Session name contains no usable characters."
    printf '%s\n' "$value"
}

alert_user() {
    local message="$1"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "DV capture" "$message" 2>/dev/null || true
    fi

    if command -v canberra-gtk-play >/dev/null 2>&1; then
        canberra-gtk-play \
            --id="complete" \
            --description="$message" \
            2>/dev/null || true
    elif command -v paplay >/dev/null 2>&1 &&
         [[ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]]; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga \
            2>/dev/null || true
    fi

    printf '\a'
}

apply_profile() {
    case "$PROFILE" in
        archival)
            FORMAT="dv2"
            EXTENSION="avi"
            REWIND=true
            AUTOSPLIT=true
            VALIDATE=true
            THUMBNAILS=true
            CHECKSUMS=true
            ;;
        raw)
            FORMAT="raw"
            EXTENSION="dv"
            REWIND=true
            AUTOSPLIT=true
            VALIDATE=true
            THUMBNAILS=true
            CHECKSUMS=true
            ;;
        quick)
            FORMAT="dv2"
            EXTENSION="avi"
            REWIND=true
            AUTOSPLIT=false
            VALIDATE=true
            THUMBNAILS=false
            CHECKSUMS=false
            ;;
        *)
            die "Unknown profile: $PROFILE"
            ;;
    esac
}

# Parse a dvgrab --timestamp filename such as:
#   TAPE0001-1999.12.25_14-30-22.avi
#
# Output:
#   raw timestamp|ISO timestamp|valid true/false
parse_recording_timestamp() {
    local filename="$1"
    local current_year
    local max_year
    local raw=""
    local iso=""
    local valid="false"

    current_year="$(date +%Y)"
    max_year=$((10#$current_year + 1))

    if [[ "$filename" =~ ([0-9]{4})\.([0-9]{2})\.([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}) ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        local hour="${BASH_REMATCH[4]}"
        local minute="${BASH_REMATCH[5]}"
        local second="${BASH_REMATCH[6]}"

        raw="${year}.${month}.${day}_${hour}-${minute}-${second}"
        iso="${year}-${month}-${day}T${hour}:${minute}:${second}"

        # Digital8/MiniDV consumer recordings are normally from the 1990s onward.
        # Permit 1980 through next year, while rejecting obvious camera-clock errors.
        if (( 10#$year >= 1980 && 10#$year <= max_year )) &&
           date -d "$iso" >/dev/null 2>&1; then
            valid="true"
        fi
    fi

    printf '%s|%s|%s\n' "$raw" "$iso" "$valid"
}

###############################################################################
# Parse arguments
###############################################################################

# First pass: identify profile so its defaults can be applied before individual
# switches override them.
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--profile" ]]; then
        ((i + 1 < ${#args[@]})) || die "--profile requires a value."
        PROFILE="${args[$((i + 1))]}"
    elif [[ "${args[$i]}" == --profile=* ]]; then
        PROFILE="${args[$i]#*=}"
    fi
done

apply_profile

while (($#)); do
    case "$1" in
        --profile)
            shift
            (($#)) || die "--profile requires a value."
            # Already applied above. Keep consuming it here.
            shift
            ;;
        --profile=*)
            shift
            ;;
        --avi)
            FORMAT="dv2"
            EXTENSION="avi"
            shift
            ;;
        --dv)
            FORMAT="raw"
            EXTENSION="dv"
            shift
            ;;
        --rewind)
            REWIND=true
            shift
            ;;
        --no-rewind)
            REWIND=false
            shift
            ;;
        --autosplit)
            AUTOSPLIT=true
            shift
            ;;
        --no-autosplit)
            AUTOSPLIT=false
            shift
            ;;
        --validate)
            VALIDATE=true
            shift
            ;;
        --no-validate)
            VALIDATE=false
            shift
            ;;
        --thumbnails)
            THUMBNAILS=true
            shift
            ;;
        --no-thumbnails)
            THUMBNAILS=false
            shift
            ;;
        --checksums)
            CHECKSUMS=true
            shift
            ;;
        --no-checksums)
            CHECKSUMS=false
            shift
            ;;
        --date-folder)
            USE_TAPE_DATE_FOLDER=true
            shift
            ;;
        --no-date-folder)
            USE_TAPE_DATE_FOLDER=false
            shift
            ;;
        --max-runtime)
            shift
            (($#)) || die "--max-runtime requires a value."
            MAX_RUNTIME="$1"
            shift
            ;;
        --max-runtime=*)
            MAX_RUNTIME="${1#*=}"
            shift
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while (($#)); do
                [[ -z "$SESSION_NAME" ]] ||
                    die "Only one session name may be supplied."
                SESSION_NAME="$1"
                shift
            done
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            [[ -z "$SESSION_NAME" ]] ||
                die "Only one session name may be supplied."
            SESSION_NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "$SESSION_NAME" ]]; then
    SESSION_NAME="TAPE-$(date +%Y%m%d-%H%M%S)"
fi

SESSION_ID="$(sanitize_name "$SESSION_NAME")"
INCOMING="${INCOMING_ROOT}/${SESSION_ID}"
FAILED="${FAILED_ROOT}/${SESSION_ID}"
LOG="${INCOMING}/${SESSION_ID}-capture.log"
BASE="${INCOMING}/${SESSION_ID}-"

###############################################################################
# Setup and checks
###############################################################################

required_commands=(
    date
    dvgrab
    ffprobe
    ffmpeg
    findmnt
    mountpoint
    python3
    sha256sum
    timeout
    tee
)

for command_name in "${required_commands[@]}"; do
    require_command "$command_name"
done

mountpoint -q "$ROOT" ||
    die "$ROOT is not a mounted filesystem."

findmnt -T "$ROOT" >/dev/null ||
    die "Unable to inspect the filesystem mounted at $ROOT."

mkdir -p "$INCOMING_ROOT" "$COMPLETED_ROOT" "$FAILED_ROOT"

if [[ -e "$INCOMING" ]]; then
    if [[ "$OVERWRITE" == true ]]; then
        rm -rf -- "$INCOMING"
    else
        die "Incoming session already exists: $INCOMING (use --overwrite to replace it)"
    fi
fi

mkdir -p "$INCOMING"

write_test="${INCOMING}/.write-test"
: >"$write_test" || die "Capture destination is not writable: $INCOMING"
rm -f -- "$write_test"

capture_started="$(date --iso-8601=seconds)"

###############################################################################
# Build dvgrab command
###############################################################################

dvgrab_command=(
    dvgrab
    --format "$FORMAT"
    --showstatus
    --timestamp
)

if [[ "$FORMAT" == "dv2" ]]; then
    dvgrab_command+=(
        --opendml
        --size 0
    )
fi

if [[ "$AUTOSPLIT" == true ]]; then
    dvgrab_command+=(--autosplit)
fi

if [[ "$REWIND" == true ]]; then
    dvgrab_command+=(--rewind)
fi

dvgrab_command+=("$BASE")

###############################################################################
# Capture
###############################################################################

{
    echo "============================================================"
    echo "Digital8/MiniDV capture"
    echo "Script version: $SCRIPT_VERSION"
    echo "Session:        $SESSION_ID"
    echo "Profile:        $PROFILE"
    echo "Format:         $FORMAT (.$EXTENSION)"
    echo "Started:        $capture_started"
    echo "Destination:    $INCOMING"
    echo "Maximum time:   $MAX_RUNTIME"
    echo "Rewind:         $REWIND"
    echo "Autosplit:      $AUTOSPLIT"
    echo "Validation:     $VALIDATE"
    echo "Thumbnails:     $THUMBNAILS"
    echo "Checksums:      $CHECKSUMS"
    echo "============================================================"
    echo
    printf 'Command: timeout --signal=INT --kill-after=30s %q ' "$MAX_RUNTIME"
    printf '%q ' "${dvgrab_command[@]}"
    echo
    echo
} | tee "$LOG"

if [[ "$REWIND" == true ]]; then
    log "Rewinding and capturing tape..."
else
    log "Capturing from the current tape position..."
fi
echo

set +e
timeout --signal=INT --kill-after=30s "$MAX_RUNTIME" \
    "${dvgrab_command[@]}" \
    2>&1 | tee -a "$LOG"

capture_status=${PIPESTATUS[0]}
set -e

capture_finished="$(date --iso-8601=seconds)"

{
    echo
    echo "dvgrab/timeout status: $capture_status"
    echo "Capture finished:      $capture_finished"
} | tee -a "$LOG"

###############################################################################
# Locate captured files and inspect recording timestamps
###############################################################################

mapfile -d '' captured_files < <(
    find "$INCOMING" \
        -maxdepth 1 \
        -type f \
        -name "*.${EXTENSION}" \
        -print0 |
    sort -z
)

if ((${#captured_files[@]} == 0)); then
    mkdir -p "$FAILED_ROOT"
    rm -rf -- "$FAILED"
    mv -- "$INCOMING" "$FAILED"
    alert_user "Capture failed: no .$EXTENSION files were created for $SESSION_ID."
    die "No .$EXTENSION files were created. Session moved to: $FAILED"
fi

earliest_valid_iso=""
earliest_valid_epoch=""
earliest_reported_raw=""
recording_date_valid_count=0
recording_date_invalid_count=0

declare -A FILE_RECORDED_RAW=()
declare -A FILE_RECORDED_ISO=()
declare -A FILE_RECORDED_VALID=()

for video in "${captured_files[@]}"; do
    filename="$(basename "$video")"
    parsed="$(parse_recording_timestamp "$filename")"

    IFS='|' read -r raw_timestamp iso_timestamp valid_timestamp <<<"$parsed"

    FILE_RECORDED_RAW["$video"]="$raw_timestamp"
    FILE_RECORDED_ISO["$video"]="$iso_timestamp"
    FILE_RECORDED_VALID["$video"]="$valid_timestamp"

    if [[ -n "$raw_timestamp" && -z "$earliest_reported_raw" ]]; then
        earliest_reported_raw="$raw_timestamp"
    fi

    if [[ "$valid_timestamp" == true ]]; then
        ((recording_date_valid_count += 1))
        epoch="$(date -d "$iso_timestamp" +%s)"

        if [[ -z "$earliest_valid_epoch" || "$epoch" -lt "$earliest_valid_epoch" ]]; then
            earliest_valid_epoch="$epoch"
            earliest_valid_iso="$iso_timestamp"
        fi
    elif [[ -n "$raw_timestamp" ]]; then
        ((recording_date_invalid_count += 1))
    fi
done

if [[ -n "$earliest_valid_iso" ]]; then
    log "Earliest valid tape recording timestamp: $earliest_valid_iso"
elif [[ -n "$earliest_reported_raw" ]]; then
    warn "Tape reported timestamp '$earliest_reported_raw', but it is implausible."
    warn "It will be preserved in the manifest but not used for folder naming."
else
    warn "No embedded tape recording timestamp was found in filenames."
fi

###############################################################################
# Validate and create sidecars
###############################################################################

processing_failed=0

for video in "${captured_files[@]}"; do
    filename="$(basename "$video")"
    stem="${video%.*}"

    echo "------------------------------------------------------------" | tee -a "$LOG"
    echo "Processing: $filename" | tee -a "$LOG"

    if [[ "$VALIDATE" == true ]]; then
        if ! ffprobe \
            -v error \
            -show_error \
            -show_format \
            -show_streams \
            -show_chapters \
            -of json \
            "$video" >"${stem}.ffprobe.json"; then

            echo "ERROR: ffprobe validation failed: $filename" | tee -a "$LOG"
            processing_failed=1
            continue
        fi
    fi

    if [[ "$THUMBNAILS" == true ]]; then
        if ! ffmpeg \
            -hide_banner \
            -loglevel error \
            -ss 5 \
            -i "$video" \
            -frames:v 1 \
            -vf "scale=640:-2" \
            -q:v 2 \
            -y \
            "${stem}.thumbnail.jpg"; then

            ffmpeg \
                -hide_banner \
                -loglevel error \
                -i "$video" \
                -frames:v 1 \
                -vf "scale=640:-2" \
                -q:v 2 \
                -y \
                "${stem}.thumbnail.jpg" ||
                echo "WARNING: Thumbnail failed: $filename" | tee -a "$LOG"
        fi
    fi

    if [[ "$CHECKSUMS" == true ]]; then
        (
            cd "$(dirname "$video")"
            sha256sum "$(basename "$video")" >"$(basename "${stem}.sha256")"
        )
    fi

    echo "Processed: $filename" | tee -a "$LOG"
done

if ((processing_failed != 0)); then
    mkdir -p "$FAILED_ROOT"
    rm -rf -- "$FAILED"
    mv -- "$INCOMING" "$FAILED"
    alert_user "Capture finished, but validation failed for $SESSION_ID."
    die "One or more files failed validation. Session moved to: $FAILED"
fi

###############################################################################
# Create manifest
###############################################################################

manifest="${INCOMING}/${SESSION_ID}-manifest.json"
hostname_value="$(hostname)"
kernel_value="$(uname -r)"
dvgrab_version="$(dvgrab --version 2>&1 | head -n 1)"
ffmpeg_version="$(ffmpeg -version 2>/dev/null | head -n 1)"

export MANIFEST_PATH="$manifest"
export SESSION_ID PROFILE FORMAT EXTENSION
export CAPTURE_STARTED="$capture_started"
export CAPTURE_FINISHED="$capture_finished"
export CAPTURE_STATUS="$capture_status"
export REWIND AUTOSPLIT VALIDATE THUMBNAILS CHECKSUMS
export SCRIPT_VERSION="$SCRIPT_VERSION"
export HOSTNAME_VALUE="$hostname_value"
export KERNEL_VALUE="$kernel_value"
export DVGRAB_VERSION="$dvgrab_version"
export FFMPEG_VERSION="$ffmpeg_version"
export EARLIEST_VALID_ISO="$earliest_valid_iso"
export EARLIEST_REPORTED_RAW="$earliest_reported_raw"
export RECORDING_DATE_VALID_COUNT="$recording_date_valid_count"
export RECORDING_DATE_INVALID_COUNT="$recording_date_invalid_count"

file_manifest_tsv="${INCOMING}/.manifest-files.tsv"
: >"$file_manifest_tsv"

for video in "${captured_files[@]}"; do
    filename="$(basename "$video")"
    size_bytes="$(stat -c '%s' "$video")"
    checksum=""

    if [[ "$CHECKSUMS" == true && -f "${video%.*}.sha256" ]]; then
        checksum="$(awk '{print $1}' "${video%.*}.sha256")"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$filename" \
        "$size_bytes" \
        "$checksum" \
        "${FILE_RECORDED_RAW[$video]}" \
        "${FILE_RECORDED_ISO[$video]}" \
        "${FILE_RECORDED_VALID[$video]}" \
        >>"$file_manifest_tsv"
done

export FILE_MANIFEST_TSV="$file_manifest_tsv"

python3 <<'PY'
import csv
import json
import os
from pathlib import Path

def env_bool(name: str) -> bool:
    return os.environ[name].lower() == "true"

files = []
with open(os.environ["FILE_MANIFEST_TSV"], newline="", encoding="utf-8") as handle:
    reader = csv.reader(handle, delimiter="\t")
    for row in reader:
        filename, size_bytes, checksum, recorded_raw, recorded_iso, recorded_valid = row
        files.append(
            {
                "filename": filename,
                "size_bytes": int(size_bytes),
                "sha256": checksum or None,
                "recording_timestamp_reported": recorded_raw or None,
                "recording_timestamp_iso": recorded_iso or None,
                "recording_timestamp_valid": recorded_valid == "true",
            }
        )

manifest = {
    "schema_version": 1,
    "script_version": os.environ["SCRIPT_VERSION"],
    "session_id": os.environ["SESSION_ID"],
    "profile": os.environ["PROFILE"],
    "capture": {
        "started": os.environ["CAPTURE_STARTED"],
        "finished": os.environ["CAPTURE_FINISHED"],
        "dvgrab_status": int(os.environ["CAPTURE_STATUS"]),
        "format": os.environ["FORMAT"],
        "extension": os.environ["EXTENSION"],
        "rewound_before_capture": env_bool("REWIND"),
        "autosplit": env_bool("AUTOSPLIT"),
        "validated_with_ffprobe": env_bool("VALIDATE"),
        "thumbnails_generated": env_bool("THUMBNAILS"),
        "checksums_generated": env_bool("CHECKSUMS"),
    },
    "recording_date": {
        "earliest_valid_iso": os.environ["EARLIEST_VALID_ISO"] or None,
        "earliest_reported_raw": os.environ["EARLIEST_REPORTED_RAW"] or None,
        "valid_file_count": int(os.environ["RECORDING_DATE_VALID_COUNT"]),
        "invalid_file_count": int(os.environ["RECORDING_DATE_INVALID_COUNT"]),
        "note": (
            "Dates are read from DV metadata by dvgrab and encoded in filenames. "
            "Camera clocks may be unset or incorrect; implausible dates are retained "
            "but not used for folder naming."
        ),
    },
    "host": {
        "hostname": os.environ["HOSTNAME_VALUE"],
        "kernel": os.environ["KERNEL_VALUE"],
    },
    "software": {
        "dvgrab": os.environ["DVGRAB_VERSION"],
        "ffmpeg": os.environ["FFMPEG_VERSION"],
    },
    "files": files,
}

path = Path(os.environ["MANIFEST_PATH"])
path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

rm -f -- "$file_manifest_tsv"

###############################################################################
# Move completed capture
###############################################################################

completed_name="$SESSION_ID"

if [[ "$USE_TAPE_DATE_FOLDER" == true && -n "$earliest_valid_iso" ]]; then
    tape_date="${earliest_valid_iso%%T*}"
    completed_name="${tape_date}_${SESSION_ID}"
fi

FINAL_DIR="${COMPLETED_ROOT}/${completed_name}"

if [[ -e "$FINAL_DIR" ]]; then
    suffix="$(date +%Y%m%d-%H%M%S)"
    FINAL_DIR="${COMPLETED_ROOT}/${completed_name}_${suffix}"
    warn "Completed folder already existed; using: $FINAL_DIR"
fi

mv -- "$INCOMING" "$FINAL_DIR"
LOG="${FINAL_DIR}/${SESSION_ID}-capture.log"

###############################################################################
# Completion
###############################################################################

{
    echo
    echo "============================================================"
    echo "Capture processing completed."
    echo "Session:      $SESSION_ID"
    echo "Profile:      $PROFILE"
    echo "Format:       $FORMAT (.$EXTENSION)"
    echo "Finished:     $capture_finished"
    echo "Files:        ${#captured_files[@]}"
    echo "Destination:  $FINAL_DIR"
    if [[ -n "$earliest_valid_iso" ]]; then
        echo "Tape date:    $earliest_valid_iso"
    elif [[ -n "$earliest_reported_raw" ]]; then
        echo "Tape date:    $earliest_reported_raw (rejected as implausible)"
    else
        echo "Tape date:    not available"
    fi
    echo "Manifest:     ${FINAL_DIR}/${SESSION_ID}-manifest.json"
    echo "============================================================"
} | tee -a "$LOG"

if ((capture_status == 124)); then
    echo
    echo "NOTE: The safety timeout stopped dvgrab."
    echo "This may be normal when the camera does not signal end-of-tape."
    alert_user "Session $SESSION_ID captured; safety timeout stopped the camera."
elif ((capture_status == 0)); then
    alert_user "Session $SESSION_ID captured and validated successfully."
else
    echo
    echo "WARNING: dvgrab returned status $capture_status."
    echo "The captured files passed enabled validation checks; inspect the log."
    alert_user "Session $SESSION_ID captured with a dvgrab warning."
fi
