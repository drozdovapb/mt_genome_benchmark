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
    memory="$(get_arg "memory" "$@")" || true
    nsub="$(get_arg "nsub" "$@")" || true
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 4 ]; then
        error "Usage (key=value): $0 read1=/path/R1.fastq read2=/path/R2.fastq ref=/path/ref.fa name=output_folder [threads=4] [memory=5] [nsub=yes]"
        error "Usage (positional): $0 <readseq1> <readseq2> <ref> <output_folder_name>"
        exit 1
    fi
    read1="$1"
    read2="$2"
    ref="$3"
    papka_name="$4"
    threads="4"          # изменено с 8 на 4
    memory="5"
    nsub=""
fi

# --- Set defaults for optional parameters ---
threads="${threads:-4}"   # изменено с 8 на 4
memory="${memory:-5}"
nsub="${nsub:-}"

# --- Validate numeric parameters ---
if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
    error "threads must be a positive integer (got '$threads')"
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

# --- Safe conda activation function (temporarily disables set -u) ---
conda_activate() {
    local env_name="$1"
    set +u
    eval "$(conda shell.bash hook)"
    conda activate "$env_name" 2>> "${OUTPUT_DIR}/assembly.log"
    set -u
}

# --- Safe conda deactivation function ---
conda_deactivate() {
    set +u
    conda deactivate 2>/dev/null || true
    set -u
}

# --- Activate conda environment ---
log "Activating environment mtgrasp..."
conda_activate mtgrasp
log "Environment activated: $CONDA_DEFAULT_ENV"

# --- Check that mtgrasp.py is available ---
if ! command -v mtgrasp.py &> /dev/null; then
    error "mtgrasp.py not found in the mtgrasp environment"
    conda_deactivate
    exit 1
fi
log "mtgrasp.py found: $(which mtgrasp.py)"

# --- Build the mtGrasp command ---
cmd_base="mtgrasp.py -r1 $read1 -r2 $read2 -o ${papka_name}_mtgraps -m $memory -r $ref -t $threads"

# Add nsub flag if set
if [[ -n "$nsub" && ( "$nsub" == "yes" || "$nsub" == "true" ) ]]; then
    cmd_nsub="-nsub"
else
    cmd_nsub=""
fi

MTGRASP_CMD="$cmd_base $cmd_nsub"
log "Command prepared: $MTGRASP_CMD"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running mtGrasp with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MTGRASP_CMD" "${papka_name}_use_res_mtgrasp.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$MTGRASP_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "mtGrasp finished successfully."
else
    error "mtGrasp exited with code $MONITOR_EXIT"
    if [ -f "${papka_name}_mtgraps/mtgrasp.log" ]; then
        log "Last lines of mtgrasp.log:"
        tail -n 10 "${papka_name}_mtgraps/mtgrasp.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

# --- Deactivate environment ---
conda_deactivate
log "mtGrasp environment deactivated"

exit $MONITOR_EXIT
