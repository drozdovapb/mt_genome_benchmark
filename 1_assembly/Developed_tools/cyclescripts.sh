#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${REPO_ROOT:-}" ]]; then
    REPO_ROOT="$(realpath -m "$REPO_ROOT")"
    export REPO_ROOT
    echo "Using REPO_ROOT from environment: $REPO_ROOT" >&2
else
    REPO_ROOT="$SCRIPT_DIR"
    while [[ "$REPO_ROOT" != "/" ]]; do
        if [[ -d "$REPO_ROOT/.git" ]]; then
            break
        fi
        REPO_ROOT="$(dirname "$REPO_ROOT")"
    done

    if [[ "$REPO_ROOT" == "/" ]]; then
        REPO_ROOT="$SCRIPT_DIR"
        echo "WARNING: Could not find repository root (no .git folder)." >&2
        echo "Using SCRIPT_DIR as REPO_ROOT: $REPO_ROOT" >&2
        echo "If you use '{{REPO_ROOT}}' in config files, this may cause issues." >&2
        echo "Set the REPO_ROOT environment variable or clone the full repository." >&2
    fi
    export REPO_ROOT
fi
# ================================================================

get_cli_arg() {
    local key="$1"
    shift
    for arg in "$@"; do
        if [[ "$arg" =~ ^${key}= ]]; then
            echo "${arg#*=}"
            return 0
        fi
    done
    return 1
}

if [[ "$*" != *"="* ]]; then
    echo "ERROR: This script now requires key=value arguments." >&2
    echo "Usage: $0 config_file=/path/to/config.txt universal_script=/path/to/script.sh assembler_name=ARC" >&2
    echo "  or:   $0 config=/path/to/config.txt script=/path/to/script.sh assembler=ARC" >&2
    echo "  assembler_name: ARC, GetOrganelle, MEANGS, MITGARD, MITObim, MitoFinder, MitoZ, NOVOPlasty, Norgal, mtGrasp" >&2
    exit 1
fi

config_file="$(get_cli_arg "config_file" "$@")" || config_file="$(get_cli_arg "config" "$@")" || {
    echo "ERROR: Missing required key 'config_file' or 'config'" >&2
    exit 1
}
universal_script="$(get_cli_arg "universal_script" "$@")" || universal_script="$(get_cli_arg "script" "$@")" || {
    echo "ERROR: Missing required key 'universal_script' or 'script'" >&2
    exit 1
}
assembler_name="$(get_cli_arg "assembler_name" "$@")" || assembler_name="$(get_cli_arg "assembler" "$@")" || {
    echo "ERROR: Missing required key 'assembler_name' or 'assembler'" >&2
    exit 1
}

LOG_DIR="./logs"
mkdir -p "$LOG_DIR" || { echo "ERROR: Failed to create log directory '$LOG_DIR'" >&2; exit 1; }

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
LOG_FILE="${LOG_DIR}/script_${assembler_name}_${TIMESTAMP}.log"
ERROR_LOG_FILE="${LOG_DIR}/errors_${assembler_name}_${TIMESTAMP}.log"
# ====================================================================

log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

error_log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] ERROR: $1" | tee -a "$ERROR_LOG_FILE" >&2
}

exec 2> >(tee -a "$ERROR_LOG_FILE")

log "Run: ${0##*/}"
log "REPO_ROOT = $REPO_ROOT"
log "Config: $config_file"
log "Assembler script: $universal_script"
log "Assembler: $assembler_name"
log "Log directory: $LOG_DIR"
log "----------------------------------------"

if [ ! -f "$config_file" ]; then
    error_log "Configuration file not found: $config_file"
    exit 1
fi
if [ ! -f "$universal_script" ]; then
    error_log "Assembler script not found: $universal_script"
    exit 1
fi
if [ ! -x "$universal_script" ]; then
    error_log "Assembler script is not executable: $universal_script"
    exit 1
fi

parse_line() {
    local line="$1"
    local -n out_args=$2
    local keys=()
    local vals=()
    out_args=()

    if [[ ! "$line" =~ = ]]; then
        error_log "Invalid format: line does not contain any '='. Expected: key1=value1 key2=value2 ..."
        return 1
    fi

    for token in $line; do
        if [[ "$token" =~ ^([a-zA-Z0-9_]+)=(.*)$ ]]; then
            keys+=("${BASH_REMATCH[1]}")
            vals+=("${BASH_REMATCH[2]}")
        else
            error_log "Invalid token: '$token' (expected key=value)"
            return 1
        fi
    done

    for i in "${!keys[@]}"; do
        key="${keys[$i]}"
        val="${vals[$i]}"
        val="${val//\{\{REPO_ROOT\}\}/$REPO_ROOT}"
        out_args+=("$key=$val")
    done
    return 0
}

# -------------------------------------------------------------------
# Main loop over config file lines
# -------------------------------------------------------------------
line_number=0
error_count=0

while IFS= read -r line || [ -n "$line" ]; do
    ((line_number++))
    # Remove comments (everything after #) and trim whitespace
    line_clean="${line%%#*}"
    line_clean=$(echo "$line_clean" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -z "$line_clean" ] && continue

    log "Processing string $line_number: $line_clean"

    if parse_line "$line_clean" args; then
        log "Arguments (key=value): ${args[*]}"
        log "Run: $universal_script ${args[*]}"
        start_time=$(date +%s)

        "$universal_script" "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
        exit_code=${PIPESTATUS[0]}

        if [ $exit_code -eq 0 ]; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            log "Successfully completed in ${duration} sec"
        else
            error_log "String $line_number: execution error (code $exit_code)"
            error_log "Arguments: ${args[*]}"
            ((error_count++))
        fi
    else
        error_log "String $line_number: parsing error"
        ((error_count++))
    fi
    log "----------------------------------------"
done < "$config_file"

log "Processed strings: $line_number"
log "Errors: $error_count"
log "Finished"

exit $((error_count > 0 ? 1 : 0))
