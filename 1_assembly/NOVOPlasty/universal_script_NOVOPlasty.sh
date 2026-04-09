#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -n "${OUTPUT_DIR:-}" ] && [ -d "$OUTPUT_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$OUTPUT_DIR/assembly.log"
    fi
}

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <config_file> <output_folder_name>"
    echo "  config_file          — path to the NOVOPlasty configuration file"
    echo "  output_folder_name   — name of the folder to be created in the script directory"
    exit 1
fi

config="$1"
papka_name="$2"

# Check if the configuration file exists and is not empty
if [ ! -f "$config" ]; then
    echo "Error: configuration file '$config' not found."
    exit 1
fi
if [ ! -s "$config" ]; then
    echo "Error: configuration file '$config' is empty."
    exit 1
fi

# Create output folder next to the script
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

# Check perl availability
if ! command -v perl &> /dev/null; then
    log "ERROR: perl not found in PATH. Make sure Perl is installed."
    exit 1
fi

# Path to NOVOPlasty script (can be overridden via environment variable)
NOVOPLASTY_PL="${NOVOPLASTY_PL:-/media/main/sandbox/ad/tool_biuld_mt_genome_links/NOVOPlasty/NOVOPlasty4.3.5.pl}"
if [ ! -f "$NOVOPLASTY_PL" ]; then
    log "ERROR: NOVOPlasty file not found at $NOVOPLASTY_PL"
    exit 1
fi
log "NOVOPlasty found: $NOVOPLASTY_PL"

# Command construction (exactly as in the original)
NOVOPLASTY_CMD="perl $NOVOPLASTY_PL -c $config"
log "Command prepared: $NOVOPLASTY_CMD"

# Find monitoring script
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# Run with or without monitoring
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running NOVOPlasty with monitoring ($MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$NOVOPLASTY_CMD" "${papka_name}_use_res_Novoplasty.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$NOVOPLASTY_CMD"
    MONITOR_EXIT=$?
fi

# Result handling
if [ $MONITOR_EXIT -eq 0 ]; then
    log "NOVOPlasty finished successfully."
else
    log "ERROR: NOVOPlasty exited with code $MONITOR_EXIT"
    if [ -f "NOVOPlasty.log" ]; then
        log "Last lines of NOVOPlasty.log:"
        tail -n 10 NOVOPlasty.log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
