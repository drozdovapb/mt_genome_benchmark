#!/bin/bash
set -euo pipefail

# --- Script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OUTPUT_DIR}/assembly.log"
    fi
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

# --- Output folder ---
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

# --- Check mitofinder availability ---
MITOFINDER_BIN="${MITOFINDER_BIN:-mitofinder}"
if ! command -v "$MITOFINDER_BIN" >/dev/null 2>&1; then
    log "Error: mitofinder not found in PATH. Make sure MitoFinder is installed and accessible."
    exit 1
fi
log "Using mitofinder: $(command -v "$MITOFINDER_BIN")"

# --- MitoFinder command construction ---
# Original command: mitofinder -j mt_genom_${papka}_posCont -1 $readseq1 -2 $readseq2 -r $ref -o 5 -p 8 -m 32 --ignore
MITOFINDER_CMD="$MITOFINDER_BIN -j mt_genom_${papka_name}_posCont -1 $readseq1 -2 $readseq2 -r $ref -o 5 -p 8 -m 32 --ignore"
log "Command prepared: $MITOFINDER_CMD"

# --- Monitoring ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MitoFinder with monitoring"
    "$MONITOR_SCRIPT" "$MITOFINDER_CMD" "${papka_name}_use_res_mitofinder.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MITOFINDER_CMD"
    MONITOR_EXIT=$?
fi

# --- Result handling ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MitoFinder finished successfully."
else
    log "Error: exit code $MONITOR_EXIT"
    # Search for MitoFinder log (may be in a subfolder or current directory)
    if [ -f "mitofinder.log" ]; then
        log "Last lines of mitofinder.log:"
        tail -n 10 mitofinder.log | while IFS= read -r line; do log "  $line"; done
    elif [ -f "log" ]; then
        log "Last lines of log:"
        tail -n 10 log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
