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
    exit 1
fi

readseq1="$1"
readseq2="$2"
papka_name="$3"

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

OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"
if [ -d "$OUTPUT_DIR" ]; then
    log "Folder '$OUTPUT_DIR' already exists."
else
    mkdir -p "$OUTPUT_DIR" || { echo "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

cd "$OUTPUT_DIR"

log "Attempting to initialize conda..."
if ! eval "$(conda shell.bash hook)" 2>> "$OUTPUT_DIR/assembly.log"; then
    log "ERROR: conda shell.bash hook failed"
    exit 1
fi
log "conda initialized"

log "Attempting to activate environment mitozEnv..."
# Set variable to avoid unbound variable error
export MKL_INTERFACE_LAYER=""
if ! conda activate mitozEnv 2>> "$OUTPUT_DIR/assembly.log"; then
    log "ERROR: failed to activate mitozEnv"
    log "List of available environments:"
    conda env list >> "$OUTPUT_DIR/assembly.log" 2>&1
    exit 1
fi
log "Environment activated: $CONDA_DEFAULT_ENV"

if ! command -v mitoz &> /dev/null; then
    log "ERROR: mitoz not found in the environment"
    conda deactivate 2>/dev/null || true
    exit 1
fi
log "mitoz found: $(which mitoz)"

MITOZ_CMD="mitoz all --outprefix ${papka_name}_use_mitoz --clade Arthropoda --requiring_taxa Arthropoda --genetic_code 5 --fq1 $readseq1 --fq2 $readseq2 --assembler megahit --skip_filter --memory 32"
log "Command prepared: $MITOZ_CMD"

MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running MitoZ with monitoring ($MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$MITOZ_CMD" "${papka_name}_use_res_mitoz.csv"
    MONITOR_EXIT=$?
else
    log "Monitor not found, running without monitoring"
    eval "$MITOZ_CMD"
    MONITOR_EXIT=$?
fi

if [ $MONITOR_EXIT -eq 0 ]; then
    log "MitoZ completed successfully"
else
    log "Error: MitoZ exited with code $MONITOR_EXIT"
    if [ -f "${papka_name}_use_mitoz/mitoz.log" ]; then
        log "Tail of mitoz.log:"
        tail -n 10 "${papka_name}_use_mitoz/mitoz.log" | while IFS= read -r line; do log "  $line"; done
    fi
fi

conda deactivate 2>/dev/null || true
log "Environment deactivated"

exit $MONITOR_EXIT
