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
    assembler="$(get_arg "assembler" "$@")" || true          # megahit, idba, metaspades
    organism="$(get_arg "organism" "$@")" || true            # -o genetic code
    processors="$(get_arg "processors" "$@")" || true        # -p
    memory="$(get_arg "memory" "$@")" || true                # -m
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 4 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq ref=/path/ref.gb name=output_folder [assembler=megahit|idba|metaspades] [organism=5] [processors=4] [memory=4]"
        error "Usage (positional): $0 <readseq1> <readseq2> <ref> <output_folder_name>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    ref="$3"
    papka_name="$4"
    assembler="megahit"
    organism="5"
    processors="4"      # изменено с 8 на 4
    memory="4"          # изменено с 32 на 4
fi

# --- Set defaults for optional parameters ---
assembler="${assembler:-megahit}"
organism="${organism:-5}"
processors="${processors:-4}"   # изменено с 8 на 4
memory="${memory:-4}"           # изменено с 32 на 4

# --- Validate assembler ---
if [[ "$assembler" != "megahit" && "$assembler" != "idba" && "$assembler" != "metaspades" ]]; then
    error "Invalid assembler: '$assembler'. Must be 'megahit', 'idba', or 'metaspades'."
    exit 1
fi

# --- Validate numeric parameters ---
if ! [[ "$processors" =~ ^[0-9]+$ ]]; then
    error "processors must be a positive integer (got '$processors')"
    exit 1
fi
if ! [[ "$memory" =~ ^[0-9]+$ ]]; then
    error "memory must be a positive integer (got '$memory')"
    exit 1
fi
if ! [[ "$organism" =~ ^[0-9]+$ ]]; then
    error "organism must be an integer (got '$organism')"
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
check_file "$ref"   "reference sequence (GenBank format)" || exit 1

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

# --- Check mitofinder availability ---
MITOFINDER_BIN="${MITOFINDER_BIN:-mitofinder}"
if ! command -v "$MITOFINDER_BIN" >/dev/null 2>&1; then
    error "mitofinder not found in PATH. Make sure MitoFinder is installed and accessible."
    exit 1
fi
log "Using mitofinder: $(command -v "$MITOFINDER_BIN")"

# --- Build the MitoFinder command ---
cmd_base="$MITOFINDER_BIN -j mt_genom_${papka_name}_posCont -1 $read1 -2 $read2 -r $ref -p $processors -m $memory -o $organism"

# Add assembler option
case "$assembler" in
    megahit)    cmd_assembler="--megahit" ;;
    idba)       cmd_assembler="--idba" ;;
    metaspades) cmd_assembler="--metaspades" ;;
esac

MITOFINDER_CMD="$cmd_base $cmd_assembler"
log "Command prepared: $MITOFINDER_CMD"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MitoFinder with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MITOFINDER_CMD" "${papka_name}_use_res_mitofinder.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$MITOFINDER_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MitoFinder finished successfully."
else
    error "MitoFinder exited with code $MONITOR_EXIT"
    if [ -f "mitofinder.log" ]; then
        log "Last lines of mitofinder.log:"
        tail -n 10 mitofinder.log | while IFS= read -r line; do log "  $line"; done
    elif [ -f "log" ]; then
        log "Last lines of log:"
        tail -n 10 log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
