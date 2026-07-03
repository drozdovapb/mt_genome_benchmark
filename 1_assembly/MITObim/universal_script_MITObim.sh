#!/bin/bash
set -euo pipefail

# --- Determine the script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function (writes to stdout and log file if OUTPUT_DIR is set) ---
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "$msg" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Error function (writes to stderr and also to log if possible) ---
error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"
    echo "$msg" >&2
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "$msg" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Helper: extract value for a given key from key=value arguments ---
get_arg() {
    local key="$1"
    shift
    for arg in "$@"; do
        if [[ "$arg" =~ ^${key}= ]]; then
            echo "${arg#*=}"
            return 0
        fi
    done
    return 1
}

# --- Parse arguments: either key=value or positional ---
if [[ "$*" == *"="* ]]; then
    # --- Key=value mode (recommended) ---
    reads="$(get_arg "reads" "$@")" || { error "Missing required key 'reads'"; exit 1; }
    ref="$(get_arg "ref" "$@")" || { error "Missing required key 'ref'"; exit 1; }
    papka_name="$(get_arg "name" "$@")" || { error "Missing required key 'name'"; exit 1; }
    
    # Optional arguments
    mode="$(get_arg "mode" "$@")" || true
    kbait="$(get_arg "kbait" "$@")" || true
    start="$(get_arg "start" "$@")" || true
    end="$(get_arg "end" "$@")" || true
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 3 ]; then
        error "Usage (key=value): $0 reads=/path/reads.fastq ref=/path/ref.fa name=output_folder [mode=quick|denovo] [kbait=31] [start=1] [end=30|100]"
        error "Usage (positional): $0 <readseq> <ref> <output_folder_name>"
        exit 1
    fi
    reads="$1"
    ref="$2"
    papka_name="$3"
    mode="quick"
    kbait=""
    start=""
    end=""
fi

# --- Set defaults for optional parameters ---
mode="${mode:-quick}"
kbait="${kbait:-}"
start="${start:-1}"
end="${end:-30}"

# --- Validate mode ---
if [[ "$mode" != "quick" && "$mode" != "denovo" ]]; then
    error "Invalid mode: '$mode'. Must be 'quick' or 'denovo'."
    exit 1
fi

# --- Validate kbait (if provided, must be a positive integer) ---
if [[ -n "$kbait" ]]; then
    if ! [[ "$kbait" =~ ^[0-9]+$ ]]; then
        error "kbait must be a positive integer (got '$kbait')"
        exit 1
    fi
fi

# --- Validate start and end (must be positive integers, end >= start) ---
if ! [[ "$start" =~ ^[0-9]+$ ]]; then
    error "start must be a positive integer (got '$start')"
    exit 1
fi
if ! [[ "$end" =~ ^[0-9]+$ ]]; then
    error "end must be a positive integer (got '$end')"
    exit 1
fi
if [[ "$end" -lt "$start" ]]; then
    error "end ($end) must be greater than or equal to start ($start)"
    exit 1
fi

# --- Function to check a file (exists, not empty, readable) ---
check_file() {
    local file="$1"
    local description="$2"
    if [ ! -e "$file" ]; then
        error "File not found: $description ('$file')"
        return 1
    fi
    if [ ! -f "$file" ]; then
        error "Not a regular file: $description ('$file')"
        return 1
    fi
    if [ ! -r "$file" ]; then
        error "File not readable: $description ('$file')"
        return 1
    fi
    if [ ! -s "$file" ]; then
        error "File is empty: $description ('$file')"
        return 1
    fi
    return 0
}

# --- Check input files ---
check_file "$reads" "reads file" || exit 1
check_file "$ref"   "reference sequence" || exit 1

# --- Build the full path to the output folder ---
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"

# --- Create the output folder ---
if [ -d "$OUTPUT_DIR" ]; then
    log "Warning: folder '$OUTPUT_DIR' already exists. The existing folder will be used."
else
    mkdir -p "$OUTPUT_DIR" || { error "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

# --- Change to the output folder ---
cd "$OUTPUT_DIR"

# --- MITObim environment setup: find MIRA (portable) ---
MIRA_CMD=""
if command -v mira &> /dev/null; then
    MIRA_CMD="mira"
    log "Found mira in PATH: $(which mira)"
elif [[ -n "${MIRA_PATH:-}" && -d "$MIRA_PATH" ]]; then
    # If MIRA_PATH is set to a directory, add it to PATH and check again
    export PATH="$MIRA_PATH:$PATH"
    if command -v mira &> /dev/null; then
        MIRA_CMD="mira"
        log "Added MIRA_PATH to PATH and found mira: $(which mira)"
    else
        log "Warning: MIRA_PATH directory exists but mira not found inside."
    fi
elif command -v mira &> /dev/null; then
    MIRA_CMD="mira"
else
    log "Warning: mira not found in PATH. MITObim may not work."
    # We don't exit because MITObim might still run if mira is not needed? But it probably is needed.
fi

# If mira was found, we already have it in PATH; otherwise, we just warn.
# The actual command will use 'mira' from PATH if available.

export LC_ALL=C
export LANG=C
log "Set LC_ALL=C and LANG=C"

# --- Find MITObim.pl executable (portable) ---
MITOBIM_CMD=""
if command -v MITObim.pl &> /dev/null; then
    MITOBIM_CMD="MITObim.pl"
    log "Found MITObim.pl in PATH: $(which MITObim.pl)"
elif [[ -n "${MITOBIM_BIN:-}" && -f "$MITOBIM_BIN" ]]; then
    MITOBIM_CMD="$MITOBIM_BIN"
    log "Using MITOBIM_BIN: $MITOBIM_BIN"
else
    error "MITObim.pl not found in PATH and MITOBIM_BIN not set or file not found."
    error "Please install MITObim and ensure 'MITObim.pl' is in your PATH,"
    error "or set the MITOBIM_BIN environment variable to the full path of the MITObim.pl script."
    exit 1
fi

# --- Build the MITObim command ---
cmd_base="$MITOBIM_CMD -start $start -end $end -sample $papka_name -ref $papka_name -readpool $reads"

if [[ "$mode" == "quick" ]]; then
    cmd_mode="--quick $ref"
elif [[ "$mode" == "denovo" ]]; then
    cmd_mode="--denovo"
fi

cmd_kbait=""
if [[ -n "$kbait" ]]; then
    cmd_kbait="--kbait $kbait"
fi

MITOBIM_CMD_FULL="$cmd_base $cmd_mode $cmd_kbait > log 2>&1"
log "Command prepared: $MITOBIM_CMD_FULL"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MITObim with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MITOBIM_CMD_FULL" "${papka_name}_use_res_mitobim.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$MITOBIM_CMD_FULL"
    MONITOR_EXIT=$?
fi

# --- Result handling ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MITObim finished successfully."
else
    error "MITObim exited with code $MONITOR_EXIT"
    if [ -f "log" ]; then
        log "Last lines of MITObim log:"
        tail -n 10 log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
