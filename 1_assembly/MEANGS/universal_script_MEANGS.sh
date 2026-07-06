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
    read1="$(get_arg "read1" "$@")" || { error "Missing required key 'read1'"; exit 1; }
    read2="$(get_arg "read2" "$@")" || { error "Missing required key 'read2'"; exit 1; }
    papka_name="$(get_arg "name" "$@")" || { error "Missing required key 'name'"; exit 1; }
    len_ins="$(get_arg "len_ins" "$@")" || { error "Missing required key 'len_ins'"; exit 1; }
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 4 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq name=output_folder len_ins=225"
        error "Usage (positional): $0 <readseq1> <readseq2> <output_folder_name> <len_ins>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    papka_name="$3"
    len_ins="$4"
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
check_file "$read1" "forward reads (R1)" || exit 1
check_file "$read2" "reverse reads (R2)" || exit 1

# --- Validate len_ins ---
if ! [[ "$len_ins" =~ ^[0-9]+$ ]]; then
    error "len_ins must be a positive integer (got '$len_ins')"
    exit 1
fi

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

# --- Find MEANGS executable (portable) ---
MEANGS_CMD=""
if command -v meangs.py &> /dev/null; then
    MEANGS_CMD="meangs.py"
    log "Found meangs.py in PATH: $(which meangs.py)"
elif [[ -n "${MEANGS_BIN:-}" && -f "$MEANGS_BIN" ]]; then
    MEANGS_CMD="$MEANGS_BIN"
    log "Using MEANGS_BIN: $MEANGS_BIN"
else
    error "meangs.py not found in PATH and MEANGS_BIN not set or file not found."
    error "Please install MEANGS and ensure 'meangs.py' is in your PATH,"
    error "or set the MEANGS_BIN environment variable to the full path of the meangs.py script."
    exit 1
fi

# --- Build the command to run MEANGS (without explicit threads/memory) ---
OUT_PREFIX="${papka_name}_mt_meangs_quick_base"
MEANGS_CMD_FULL="$MEANGS_CMD -1 $read1 -2 $read2 -o $OUT_PREFIX -i $len_ins"
log "Command prepared: $MEANGS_CMD_FULL"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MEANGS with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MEANGS_CMD_FULL" "${papka_name}_use_res_MEANGS.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$MEANGS_CMD_FULL"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MEANGS finished successfully."
else
    error "MEANGS exited with code $MONITOR_EXIT"
    if [ -f "${OUT_PREFIX}/meangs.log" ]; then
        log "Last lines of meangs.log:"
        tail -n 10 "${OUT_PREFIX}/meangs.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
