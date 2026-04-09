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
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <readseq> <ref> <output_folder_name>"
    echo "  readseq             — path to the reads file (fastq)"
    echo "  ref                 — path to the reference sequence (fasta)"
    echo "  output_folder_name  — name of the folder to be created in the script directory"
    exit 1
fi

readseq="$1"
ref="$2"
papka_name="$3"

# --- Input file validation ---
for file in "$readseq" "$ref"; do
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

# --- MITObim environment setup ---
MIRA_PATH="${MIRA_PATH:-/media/secondary/apps/mira_4.0.2_linux-gnu_x86_64_static/bin}"
if [ -d "$MIRA_PATH" ]; then
    export PATH="$MIRA_PATH:$PATH"
    log "Added to PATH: $MIRA_PATH"
else
    log "Warning: mira path not found: $MIRA_PATH. MITObim may not work."
fi

export LC_ALL=C
export LANG=C
log "Set LC_ALL=C and LANG=C"

# --- Path to MITObim.pl ---
MITOBIM_BIN="${MITOBIM_BIN:-/media/main/sandbox/ad/tool_biuld_mt_genome_links/MITObim/MITObim.pl}"
if [ ! -x "$MITOBIM_BIN" ]; then
    log "Error: MITObim.pl not found or not executable: $MITOBIM_BIN"
    exit 1
fi

# --- MITObim command construction (with -end 100 and output redirection) ---
MITOBIM_CMD="$MITOBIM_BIN -sample $papka_name -ref $papka_name -readpool $readseq --quick $ref -end 100 &> log"
log "Command prepared: $MITOBIM_CMD"

# --- Monitoring ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MITObim with monitoring"
    "$MONITOR_SCRIPT" "$MITOBIM_CMD" "${papka_name}_use_res_mitobim.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MITOBIM_CMD"
    MONITOR_EXIT=$?
fi

# --- Result handling ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "MITObim finished successfully."
else
    log "Error: exit code $MONITOR_EXIT"
    if [ -f "log" ]; then
        log "Last lines of MITObim log:"
        tail -n 10 log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
