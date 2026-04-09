#!/bin/bash
set -euo pipefail

# --- Script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -n "${OUTPUT_DIR:-}" ] && [ -d "$OUTPUT_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$OUTPUT_DIR/assembly.log"
    fi
}

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

# --- Argument check ---
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <readseq1> <readseq2> <ref> <output_folder_name>"
    echo "  readseq1            — path to the forward reads file (R1)"
    echo "  readseq2            — path to the reverse reads file (R2)"
    echo "  ref                 — path to the reference sequence (fasta)"
    echo "  output_folder_name  — name of the folder to be created in the script directory"
    exit 1
fi

readseq1="$1"
readseq2="$2"
ref="$3"
papka_name="$4"

# --- Input file validation ---
for file in "$readseq1" "$readseq2" "$ref"; do
    if [ ! -f "$file" ]; then
        echo "Error: file '$file' not found."
        exit 1
    fi
    if [ ! -s "$file" ]; then
        echo "Error: file '$file' is empty."
        exit 1
    fi
done

# --- Create output folder next to the script ---
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

# --- Activate conda environment ---
log "Activating environment mtgrasp..."
conda_activate mtgrasp
log "Environment activated: $CONDA_DEFAULT_ENV"

# --- Check that mtgrasp.py is available ---
if ! command -v mtgrasp.py &> /dev/null; then
    log "ERROR: mtgrasp.py not found in the mtgrasp environment"
    conda_deactivate
    exit 1
fi
log "mtgrasp.py found: $(which mtgrasp.py)"

# --- Command construction (exactly as in the original) ---
MTGRASP_CMD="mtgrasp.py -r1 $readseq1 -r2 $readseq2 -o ${papka_name}_mtgraps -m 5 -r $ref -nsub -t 8"
log "Command prepared: $MTGRASP_CMD"

# --- Find monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running mtgrasp with monitoring ($MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MTGRASP_CMD" "${papka_name}_use_res_mygraps.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MTGRASP_CMD"
    MONITOR_EXIT=$?
fi

# --- Result handling ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "mtgrasp finished successfully."
else
    log "ERROR: mtgrasp exited with code $MONITOR_EXIT"
    # Try to locate mtgrasp log (if it is created)
    if [ -f "${papka_name}_mtgraps/mtgrasp.log" ]; then
        log "Last lines of mtgrasp.log:"
        tail -n 10 "${papka_name}_mtgraps/mtgrasp.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

# --- Deactivate environment ---
conda_deactivate
log "mtgrasp environment deactivated"

exit $MONITOR_EXIT
