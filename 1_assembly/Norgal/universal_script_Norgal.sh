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

    # Optional arguments (defaults set later)
    threads="$(get_arg "threads" "$@")" || true
    blast="$(get_arg "blast" "$@")" || true
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 3 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq name=output_folder [threads=8] [blast=yes]"
        error "Usage (positional): $0 <readseq1> <readseq2> <output_folder_name>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    papka_name="$3"
    threads="8"
    blast=""
fi

# --- Set defaults for optional parameters ---
threads="${threads:-8}"
blast="${blast:-}"

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

# --- Check input files ---
check_file "$read1" "forward reads (R1)" || exit 1
check_file "$read2" "reverse reads (R2)" || exit 1

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

# --- Find Norgal executable (portable) ---
NORGAL_CMD=""
if command -v norgal &> /dev/null; then
    NORGAL_CMD="norgal"
    log "Found norgal in PATH: $(which norgal)"
elif command -v norgal.py &> /dev/null; then
    NORGAL_CMD="norgal.py"
    log "Found norgal.py in PATH: $(which norgal.py)"
elif [[ -n "${NORGAL_PY:-}" && -f "$NORGAL_PY" ]]; then
    # If NORGAL_PY is set to a .py file, run it with python
    # Check if python is available
    if command -v python &> /dev/null; then
        NORGAL_CMD="python $NORGAL_PY"
        log "Using NORGAL_PY: $NORGAL_PY"
    else
        error "python not found, but NORGAL_PY is set to a Python script."
        exit 1
    fi
else
    error "norgal not found in PATH and NORGAL_PY not set or file not found."
    error "Please install norgal and add it to PATH, or set the NORGAL_PY environment variable"
    error "to the full path of the norgal.py script."
    exit 1
fi

# --- Build the Norgal command ---
cmd_base="$NORGAL_CMD -i $read1 $read2 -o ${papka_name}_norgal_output -t $threads"

# Add blast flag if set to yes/true
if [[ -n "$blast" && ( "$blast" == "yes" || "$blast" == "true" ) ]]; then
    cmd_blast="--blast"
else
    cmd_blast=""
fi

NORGAL_CMD_FULL="$cmd_base $cmd_blast"
log "Command prepared: $NORGAL_CMD_FULL"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running Norgal with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$NORGAL_CMD_FULL" "${papka_name}_use_res_Norgal.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$NORGAL_CMD_FULL"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "Norgal finished successfully."
else
    error "Norgal exited with code $MONITOR_EXIT"
    if [ -f "${papka_name}_norgal_output/norgal.log" ]; then
        log "Last lines of norgal.log:"
        tail -n 10 "${papka_name}_norgal_output/norgal.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
