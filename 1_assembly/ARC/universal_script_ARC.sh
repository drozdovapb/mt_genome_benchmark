#!/bin/bash
set -euo pipefail

# --- Determine the directory where this script is located ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Check arguments ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <config_file> <output_folder_name>"
    echo "  config_file          — path to the ARC configuration file"
    echo "  output_folder_name   — name of the folder to be created in the script directory"
    exit 1
fi

config="$1"
papka_name="$2"

# --- Check if the configuration file exists and is not empty ---
if [ ! -f "$config" ]; then
    echo "Error: configuration file '$config' not found."
    exit 1
fi
if [ ! -s "$config" ]; then
    echo "Error: configuration file '$config' is empty."
    exit 1
fi

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

# --- Activate Conda environment ---
eval "$(conda shell.bash hook)"
if ! conda activate ARS_python_2.7 2>/dev/null; then
    log "Error: failed to activate environment ARS_python_2.7"
    exit 1
fi
log "Conda environment activated: ARC_env"

# --- Path to the ARC executable ---
ARC_BIN="${ARC_BIN:-/media/main/sandbox/ad/tool_biuld_mt_genome_links/ARC/bin/ARC}"

if [ ! -x "$ARC_BIN" ]; then
    log "Error: ARC executable not found or not executable: $ARC_BIN"
    conda deactivate
    exit 1
fi

# --- Build the command to run ARC ---
ARC_CMD="$ARC_BIN -c $config"
log "Command prepared: $ARC_CMD"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running ARC with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$ARC_CMD" "${papka_name}_use_res_ARC.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$ARC_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "ARC finished successfully."
else
    log "Error: ARC exited with code $MONITOR_EXIT"
    if [ -f "ARC.log" ]; then
        log "Last lines of ARC.log:"
        tail -n 10 ARC.log | while IFS= read -r line; do log "  $line"; done
    fi
fi

# --- Deactivate the Conda environment ---
conda deactivate
log "Conda environment deactivated"

exit $MONITOR_EXIT
```
