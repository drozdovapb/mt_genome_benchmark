#!/bin/bash
set -euo pipefail

# --- Determine the script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Check arguments ---
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <readseq1> <readseq2> <ref> <output_folder_name>"
    echo "  readseq1             — path to the forward reads file (R1)"
    echo "  readseq2             — path to the reverse reads file (R2)"
    echo "  ref                  — path to the reference sequence"
    echo "  output_folder_name   — name of the folder to be created in the script directory"
    exit 1
fi

readseq1="$1"
readseq2="$2"
ref="$3"
papka_name="$4"

# --- Check existence of input files ---
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

# --- Build the full path to the output folder ---
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"

# --- Create the output folder ---
if [ -d "$OUTPUT_DIR" ]; then
    log "Warning: folder '$OUTPUT_DIR' already exists. The existing folder will be used."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

# --- Change to the output folder ---
cd "$OUTPUT_DIR"

# --- Original command (unchanged, but wrapped for eval) ---
# Note: the original script used monitor_PPID2407_2.sh with a quoted command,
# but here we will construct the string so that it is passed to the monitor correctly.
# The get_organelle_from_reads.py command remains exactly as in the original example.
GETORG_CMD="/media/main/sandbox/ad/tool_biuld_mt_genome_links/GetOrganelle-1.7.4.1/get_organelle_from_reads.py -1 $readseq1 -2 $readseq2 -R 10 -F animal_mt -t 16 -s $ref -o ${papka_name}_rna_getorgan -R 10"
log "Command prepared: $GETORG_CMD"

# --- Determine the monitoring script (use the improved version with eval) ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running GetOrganelle with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$GETORG_CMD" "${papka_name}_use_res_getorganel.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$GETORG_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "GetOrganelle finished successfully."
else
    log "Error: GetOrganelle exited with code $MONITOR_EXIT"
    # Try to locate the GetOrganelle log — it is usually located inside the output folder
    if [ -f "${papka_name}_rna_getorgan/run.log" ]; then
        log "Last lines of run.log:"
        tail -n 10 "${papka_name}_rna_getorgan/run.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
```
