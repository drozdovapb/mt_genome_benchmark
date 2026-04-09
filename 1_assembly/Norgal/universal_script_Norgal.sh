#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -n "${OUTPUT_DIR:-}" ] && [ -d "$OUTPUT_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$OUTPUT_DIR/assembly.log"
    fi
}

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <readseq1> <readseq2> <output_folder_name>"
    echo "  readseq1            — path to the forward reads file (R1)"
    echo "  readseq2            — path to the reverse reads file (R2)"
    echo "  output_folder_name  — name of the folder to be created in the script directory"
    exit 1
fi

readseq1="$1"
readseq2="$2"
papka_name="$3"

# Input file validation
for file in "$readseq1" "$readseq2"; do
    if [ ! -f "$file" ]; then
        echo "Error: file '$file' not found."
        exit 1
    fi
    if [ ! -s "$file" ]; then
        echo "Error: file '$file' is empty."
        exit 1
    fi
done

# Create output folder next to the script
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

# Check python availability (may be needed to run norgal.py)
if ! command -v python &> /dev/null; then
    log "ERROR: python not found in PATH. Make sure Python is installed."
    exit 1
fi

# Path to norgal.py (can be overridden via environment variable)
NORGAL_PY="${NORGAL_PY:-/media/secondary/apps/norgal/norgal/norgal.py}"
if [ ! -f "$NORGAL_PY" ]; then
    log "ERROR: norgal.py file not found at $NORGAL_PY"
    exit 1
fi
log "norgal.py found: $NORGAL_PY"

# Command construction (exactly as in the original)
NORGAL_CMD="python $NORGAL_PY -i $readseq1 $readseq2 -o ${papka_name}_norgal_output -t 8 --blast"
log "Command prepared: $NORGAL_CMD"

# Find monitoring script
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# Run with or without monitoring
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running Norgal with monitoring ($MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$NORGAL_CMD" "${papka_name}_use_res_Norgal.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$NORGAL_CMD"
    MONITOR_EXIT=$?
fi

# Result handling
if [ $MONITOR_EXIT -eq 0 ]; then
    log "Norgal finished successfully."
else
    log "ERROR: Norgal exited with code $MONITOR_EXIT"
    # Try to locate Norgal log (if created)
    if [ -f "${papka_name}_norgal_output/norgal.log" ]; then
        log "Last lines of norgal.log:"
        tail -n 10 "${papka_name}_norgal_output/norgal.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
