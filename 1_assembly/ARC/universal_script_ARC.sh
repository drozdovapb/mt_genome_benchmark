#!/bin/bash
set -euo pipefail

# --- Determine the script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Logging function (writes to stdout and log file if OUTPUT_DIR is set) ---
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "$msg" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Error function (writes to stderr and also to log if possible) ---
error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"
    echo "$msg" >&2
    if [ -d "${OUTPUT_DIR:-}" ]; then
        echo "$msg" >> "${OUTPUT_DIR}/assembly.log"
    fi
}

# --- Helper: extract value for a given key from key=value arguments ---
get_arg() {
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

# --- Parse arguments: either key=value or positional ---
if [[ "$*" == *"="* ]]; then
    # --- Key=value mode (recommended) ---
    config="$(get_arg "config" "$@")" || { error "Missing required key 'config'"; exit 1; }
    papka_name="$(get_arg "name" "$@")" || { error "Missing required key 'name'"; exit 1; }
else
    # --- Positional mode (backward compatibility) ---
    if [ "$#" -ne 2 ]; then
        error "Usage (key=value): $0 config=/path/config.txt name=output_folder"
        error "Usage (positional): $0 <config_file> <output_folder_name>"
        exit 1
    fi
    config="$1"
    papka_name="$2"
fi

# --- Check if the configuration file exists and is not empty ---
if [ ! -f "$config" ]; then
    error "Configuration file not found: '$config'"
    exit 1
fi
if [ ! -s "$config" ]; then
    error "Configuration file is empty: '$config'"
    exit 1
fi

# --- Function to check data files referenced in the ARC config ---
check_data_files() {
    local cfg="$1"
    local cfg_dir="$(dirname "$cfg")"
    local missing_files=()
    local checked_keys=("read1" "read2" "reference")

    for key in "${checked_keys[@]}"; do
        # Extract value after '=' (ignore leading/trailing spaces)
        local val
        val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
        if [ -n "$val" ]; then
            # Convert relative path to absolute path relative to config directory
            if [[ "$val" != /* ]]; then
                val="${cfg_dir}/${val}"
            fi
            if [ ! -f "$val" ]; then
                missing_files+=("$key -> $val")
            fi
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        error "The following required data files are missing or not readable:"
        for entry in "${missing_files[@]}"; do
            error "  $entry"
        done
        return 1
    fi
    return 0
}

# --- Check referenced data files ---
if ! check_data_files "$config"; then
    exit 1
fi

# --- Build the full path to the output folder ---
OUTPUT_DIR="${SCRIPT_DIR}/${papka_name}"

# --- Create the output folder ---
if [ -d "$OUTPUT_DIR" ]; then
    log "Warning: folder '$OUTPUT_DIR' already exists. The existing folder will be used."
else
    mkdir -p "$OUTPUT_DIR" || { error "Failed to create folder '$OUTPUT_DIR'"; exit 1; }
    log "Folder created: $OUTPUT_DIR"
fi

# --- Change to the output folder ---
cd "$OUTPUT_DIR"

# --- Activate Conda environment ---
eval "$(conda shell.bash hook)"
if ! conda activate ARS_python_2.7 2>/dev/null; then
    error "Failed to activate Conda environment 'ARS_python_2.7'"
    exit 1
fi
log "Conda environment activated: ARC_env"

# --- Find ARC executable (portable) ---
ARC_CMD=""
if command -v ARC &> /dev/null; then
    ARC_CMD="ARC"
    log "Found ARC in PATH: $(which ARC)"
elif [[ -n "${ARC_BIN:-}" && -x "$ARC_BIN" ]]; then
    ARC_CMD="$ARC_BIN"
    log "Using ARC_BIN: $ARC_BIN"
else
    error "ARC not found in PATH and ARC_BIN not set or not executable."
    error "Please ensure ARC is installed and available in your PATH,"
    error "or set the ARC_BIN environment variable to the full path of the ARC executable."
    conda deactivate
    exit 1
fi

# --- Build the command to run ARC ---
ARC_CMD_FULL="$ARC_CMD -c $config"
log "Command prepared: $ARC_CMD_FULL"

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
    "$MONITOR_SCRIPT" "$ARC_CMD_FULL" "${papka_name}_use_res_ARC.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$ARC_CMD_FULL"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "ARC finished successfully."
else
    error "ARC exited with code $MONITOR_EXIT"
    if [ -f "ARC.log" ]; then
        log "Last lines of ARC.log:"
        tail -n 10 ARC.log | while IFS= read -r line; do log "  $line"; done
    fi
fi

# --- Deactivate the Conda environment ---
conda deactivate
log "Conda environment deactivated"

exit $MONITOR_EXIT
