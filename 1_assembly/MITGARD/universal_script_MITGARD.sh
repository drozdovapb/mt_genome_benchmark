#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <readseq1> <readseq2> <ref> <output_folder_name>"
    exit 1
fi

readseq1="$1"
readseq2="$2"
ref="$3"
papka_name="$4"

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

OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

MITGARD_BIN="${MITGARD_BIN:-/media/main/sandbox/ad/tool_biuld_mt_genome_links/MITGARD/bin/MITGARD.py}"
if [ ! -x "$MITGARD_BIN" ]; then
    log "Error: MITGARD not found or not executable: $MITGARD_BIN"
    exit 1
fi

MITGARD_CMD="$MITGARD_BIN -s $papka_name -1 $readseq1 -2 $readseq2 -R $ref -M 32G -c 16"
log "Command prepared: $MITGARD_CMD"

MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MITGARD with monitoring"
    "$MONITOR_SCRIPT" "$MITGARD_CMD" "${papka_name}_use_res_MITGARD.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MITGARD_CMD"
    MONITOR_EXIT=$?
fi

if [ $MONITOR_EXIT -eq 0 ]; then
    log "MITGARD finished successfully."
else
    log "Error: exit code $MONITOR_EXIT"
    if [ -f "${papka_name}/mitgard.log" ]; then
        log "Log tail:"
        tail -n 10 "${papka_name}/mitgard.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
