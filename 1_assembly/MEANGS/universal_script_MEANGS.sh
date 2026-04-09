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
    echo "Usage: $0 <readseq1> <readseq2> <output_folder_name> <len_ins>"
    exit 1
fi

readseq1="$1"
readseq2="$2"
papka_name="$3"
len_ins="$4"

# Check input files
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

# Check len_ins
if ! [[ "$len_ins" =~ ^[0-9]+$ ]]; then
    echo "Error: len_ins must be a positive integer."
    exit 1
fi

# Warning about spaces
for var in readseq1 readseq2 papka_name; do
    if [[ "${!var}" =~ \  ]]; then
        echo "Warning: path contains spaces: ${!var}"
        echo "The script may not work correctly. Please ensure paths do not contain spaces."
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

MEANGS_BIN="${MEANGS_BIN:-/media/secondary/apps/MEANGS/meangs.py}"
if [ ! -x "$MEANGS_BIN" ]; then
    log "Error: MEANGS not found or not executable: $MEANGS_BIN"
    exit 1
fi

OUT_PREFIX="${papka_name}_mt_meangs_quick_base"
MEANGS_CMD="$MEANGS_BIN -1 $readseq1 -2 $readseq2 -o $OUT_PREFIX -t 8 -i $len_ins"
log "Command prepared: $MEANGS_CMD"

MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MEANGS with monitoring"
    "$MONITOR_SCRIPT" "$MEANGS_CMD" "${papka_name}_use_res_MEANGS.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MEANGS_CMD"
    MONITOR_EXIT=$?
fi

if [ $MONITOR_EXIT -eq 0 ]; then
    log "MEANGS finished successfully."
else
    log "Error: exit code $MONITOR_EXIT"
    if [ -f "${OUT_PREFIX}/meangs.log" ]; then
        log "Log tail:"
        tail -n 10 "${OUT_PREFIX}/meangs.log" | while read line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
```
