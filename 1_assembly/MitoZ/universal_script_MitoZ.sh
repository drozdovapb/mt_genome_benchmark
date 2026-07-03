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
    clade="$(get_arg "clade" "$@")" || { error "Missing required key 'clade'"; exit 1; }
    genetic_code="$(get_arg "genetic_code" "$@")" || { error "Missing required key 'genetic_code'"; exit 1; }

    # Optional arguments (defaults set later)
    assembler="$(get_arg "assembler" "$@")" || true
    memory="$(get_arg "memory" "$@")" || true
    skip_filter="$(get_arg "skip_filter" "$@")" || true
else
    # --- Positional mode (backward compatibility) ---
    # Now expects 5 arguments: read1 read2 name clade genetic_code
    if [ "$#" -ne 5 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq name=output_folder clade=Arthropoda genetic_code=5 [assembler=megahit] [memory=12] [skip_filter=yes]"
        error "Usage (positional): $0 <readseq1> <readseq2> <output_folder_name> <clade> <genetic_code>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    papka_name="$3"
    clade="$4"
    genetic_code="$5"
    assembler="megahit"
    memory="12"
    skip_filter=""
fi

# --- Set defaults for optional parameters ---
assembler="${assembler:-megahit}"
memory="${memory:-12}"
skip_filter="${skip_filter:-}"

# --- Validate numeric parameters ---
if ! [[ "$genetic_code" =~ ^[0-9]+$ ]]; then
    error "genetic_code must be an integer (got '$genetic_code')"
    exit 1
fi
if ! [[ "$memory" =~ ^[0-9]+$ ]]; then
    error "memory must be a positive integer (got '$memory')"
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

# --- Activate conda environment for MitoZ ---
log "Attempting to initialize conda..."
if ! eval "$(conda shell.bash hook)" 2>> "$OUTPUT_DIR/assembly.log"; then
    error "conda shell.bash hook failed"
    exit 1
fi
log "conda initialized"

log "Attempting to activate environment mitozEnv..."
export MKL_INTERFACE_LAYER=""  # Avoid unbound variable
if ! conda activate mitozEnv 2>> "$OUTPUT_DIR/assembly.log"; then
    error "Failed to activate mitozEnv. Available environments:"
    conda env list >> "$OUTPUT_DIR/assembly.log" 2>&1
    exit 1
fi
log "Environment activated: $CONDA_DEFAULT_ENV"

# --- Check that mitoz is available ---
if ! command -v mitoz &> /dev/null; then
    error "mitoz not found in the environment"
    conda deactivate 2>/dev/null || true
    exit 1
fi
log "mitoz found: $(which mitoz)"

# --- Build the MitoZ command ---
cmd_base="mitoz all --outprefix ${papka_name}_use_mitoz --clade $clade --requiring_taxa $clade --genetic_code $genetic_code --fq1 $read1 --fq2 $read2 --assembler $assembler --memory $memory"

# Add skip_filter flag if set
if [[ -n "$skip_filter" && ( "$skip_filter" == "yes" || "$skip_filter" == "true" ) ]]; then
    cmd_skip="--skip_filter"
else
    cmd_skip=""
fi

MITOZ_CMD="$cmd_base $cmd_skip"
log "Command prepared: $MITOZ_CMD"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MitoZ with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MITOZ_CMD" "${papka_name}_use_res_mitoz.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$MITOZ_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MitoZ finished successfully."
else
    error "MitoZ exited with code $MONITOR_EXIT"
    if [ -f "${papka_name}_use_mitoz/mitoz.log" ]; then
        log "Last lines of mitoz.log:"
        tail -n 10 "${papka_name}_use_mitoz/mitoz.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

# --- Deactivate conda environment ---
conda deactivate 2>/dev/null || true
log "Conda environment deactivated"

exit $MONITOR_EXIT
