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
    ref="$(get_arg "ref" "$@")" || { error "Missing required key 'ref'"; exit 1; }
    papka_name="$(get_arg "name" "$@")" || { error "Missing required key 'name'"; exit 1; }

    # Optional arguments (defaults set later)
    threads="$(get_arg "threads" "$@")" || true
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 4 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq ref=/path/ref.fa name=output_folder [threads=4]"
        error "Usage (positional): $0 <readseq1> <readseq2> <ref> <output_folder_name>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    ref="$3"
    papka_name="$4"
    threads="4"
fi

# --- Set defaults for optional parameters ---
threads="${threads:-4}"

# --- Validate numeric parameters ---
if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
    error "threads must be a positive integer (got '$threads')"
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

# --- Check all input files ---
check_file "$read1" "forward reads (R1)" || exit 1
check_file "$read2" "reverse reads (R2)" || exit 1
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

# --- Find GetOrganelle executable (portable) ---
GETORG_CMD=""
if command -v get_organelle_from_reads.py &> /dev/null; then
    GETORG_CMD="get_organelle_from_reads.py"
    log "Found get_organelle_from_reads.py in PATH: $(which get_organelle_from_reads.py)"
elif [[ -n "${GETORG_BIN:-}" && -f "$GETORG_BIN" ]]; then
    GETORG_CMD="$GETORG_BIN"
    log "Using GETORG_BIN: $GETORG_BIN"
else
    error "get_organelle_from_reads.py not found in PATH and GETORG_BIN not set or file not found."
    error "Please install GetOrganelle and ensure 'get_organelle_from_reads.py' is in your PATH,"
    error "or set the GETORG_BIN environment variable to the full path of the script."
    exit 1
fi

# --- Build the command to run GetOrganelle (with configurable threads) ---
# Note: the original command has -R 10 twice; we preserve it.
GETORG_CMD_FULL="$GETORG_CMD -1 $read1 -2 $read2 -R 10 -F animal_mt -t $threads -s $ref -o ${papka_name}_rna_getorgan -R 10"
log "Command prepared: $GETORG_CMD_FULL"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running GetOrganelle with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$GETORG_CMD_FULL" "${papka_name}_use_res_getorganel.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$GETORG_CMD_FULL"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "GetOrganelle finished successfully."
else
    error "GetOrganelle exited with code $MONITOR_EXIT"
    # Try to locate the GetOrganelle log — it is usually inside the output subfolder
    if [ -f "${papka_name}_rna_getorgan/run.log" ]; then
        log "Last lines of run.log:"
        tail -n 10 "${papka_name}_rna_getorgan/run.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
