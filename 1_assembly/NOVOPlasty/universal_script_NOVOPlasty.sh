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
            local val="${arg#*=}"
            # Trim leading/trailing spaces, tabs, and carriage return
            val="$(echo -n "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r$//')"
            echo "$val"
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
        error "Usage (key=value): $0 config=/path/to/config.txt name=output_folder"
        error "Usage (positional): $0 <config_file> <output_folder_name>"
        exit 1
    fi
    config="$1"
    papka_name="$2"
fi

# --- Debug: show exact path with quotes ---
log "DEBUG: config path = '$config'"
log "DEBUG: config path length = ${#config}"

# --- Check if the configuration file exists and is not empty ---
if [ ! -f "$config" ]; then
    error "Configuration file not found: '$config'"
    error "Please check that the path is correct and the file is readable."
    
    # Check if directory exists
    config_dir="$(dirname "$config")"
    if [ ! -d "$config_dir" ]; then
        error "Directory does not exist: $config_dir"
    else
        error "Directory exists, but file is not present or not accessible."
        error "Listing directory contents (up to 20 files):"
        ls -la "$config_dir" | head -20 >&2 || true
    fi
    exit 1
fi

if [ ! -s "$config" ]; then
    error "Configuration file is empty: '$config'"
    exit 1
fi

# --- Function to check data files referenced in the NOVOPlasty config (supports batch mode) ---
check_novoplasty_files() {
    local cfg="$1"
    local cfg_dir="$(dirname "$cfg")"
    local missing_files=()
    local repo_root="${REPO_ROOT:-}"

    # Extract key values
    local seed_input=$(grep -E "^[[:space:]]*Seed Input[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
    local forward_reads=$(grep -E "^[[:space:]]*Forward reads[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
    local reverse_reads=$(grep -E "^[[:space:]]*Reverse reads[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
    local ref_seq=$(grep -E "^[[:space:]]*Reference sequence[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
    local project_line=$(grep -E "^[[:space:]]*Project name[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')

    # Detect batch mode
    if [[ "$seed_input" == "batch" ]] || [[ "$forward_reads" == "batch" ]] || [[ "$reverse_reads" == "batch" ]]; then
        # Extract batch file path from Project name
        if [[ "$project_line" =~ batch:(.+) ]]; then
            local batch_file="${BASH_REMATCH[1]}"
            # Resolve relative path
            if [[ "$batch_file" != /* ]]; then
                batch_file="${cfg_dir}/${batch_file}"
            fi
            if [ ! -f "$batch_file" ]; then
                error "Batch file not found: $batch_file"
                return 1
            fi
            # Read batch file lines (1: project name, 2: reference, 3: R1, 4: R2)
            local batch_ref batch_read1 batch_read2
            batch_ref=$(sed -n '2p' "$batch_file" | tr -d '\r')
            batch_read1=$(sed -n '3p' "$batch_file" | tr -d '\r')
            batch_read2=$(sed -n '4p' "$batch_file" | tr -d '\r')

            # Replace {{REPO_ROOT}} if present
            if [[ -n "$repo_root" ]]; then
                batch_ref="${batch_ref//\{\{REPO_ROOT\}\}/$repo_root}"
                batch_read1="${batch_read1//\{\{REPO_ROOT\}\}/$repo_root}"
                batch_read2="${batch_read2//\{\{REPO_ROOT\}\}/$repo_root}"
            fi

            # Check files
            for file in "$batch_ref" "$batch_read1" "$batch_read2"; do
                if [ ! -f "$file" ]; then
                    missing_files+=("$file")
                fi
            done
        else
            error "Batch mode detected but no batch file path found in Project name. Expected format: batch:/path/to/batch"
            return 1
        fi
    else
        # Regular mode: check read1, read2, reference, Genome
        local checked_keys=("read1" "read2" "reference" "Genome")
        for key in "${checked_keys[@]}"; do
            local val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$cfg" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')
            if [ -n "$val" ]; then
                if [[ -n "$repo_root" ]]; then
                    val="${val//\{\{REPO_ROOT\}\}/$repo_root}"
                fi
                if [[ "$val" != /* ]]; then
                    val="${cfg_dir}/${val}"
                fi
                if [ ! -f "$val" ]; then
                    missing_files+=("$key -> $val")
                fi
            fi
        done
    fi

    if [ ${#missing_files[@]} -gt 0 ]; then
        error "The following required data files from NOVOPlasty config are missing or not readable:"
        for entry in "${missing_files[@]}"; do
            error "  $entry"
        done
        return 1
    fi
    return 0
}

# --- Check referenced data files ---
if ! check_novoplasty_files "$config"; then
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

# --- Check perl availability ---
if ! command -v perl &> /dev/null; then
    error "perl not found in PATH. Make sure Perl is installed."
    exit 1
fi
log "perl found: $(which perl)"

# --- Find NOVOPlasty executable or script (portable) ---
NOVO_CMD=""
if command -v NOVOPlasty &> /dev/null; then
    NOVO_CMD="NOVOPlasty"
    log "Found NOVOPlasty in PATH: $(which NOVOPlasty)"
elif command -v NOVOPlasty.pl &> /dev/null; then
    NOVO_CMD="NOVOPlasty.pl"
    log "Found NOVOPlasty.pl in PATH: $(which NOVOPlasty.pl)"
elif [[ -n "${NOVOPLASTY_PL:-}" && -f "$NOVOPLASTY_PL" ]]; then
    NOVO_CMD="perl $NOVOPLASTY_PL"
    log "Using NOVOPLASTY_PL: $NOVOPLASTY_PL"
else
    error "NOVOPlasty not found in PATH and NOVOPLASTY_PL not set or file not found."
    error "Please install NOVOPlasty and add it to PATH, or set NOVOPLASTY_PL to the path of NOVOPlasty.pl"
    exit 1
fi

# --- Build the NOVOPlasty command ---
NOVOPLASTY_CMD="$NOVO_CMD -c $config"
log "Command prepared: $NOVOPLASTY_CMD"

# --- Determine the monitoring script ---
MONITOR_SCRIPT=""
if command -v monitor_PPID2407_2.sh >/dev/null 2>&1; then
    MONITOR_SCRIPT="monitor_PPID2407_2.sh"
elif [ -x "$SCRIPT_DIR/monitor_PPID2407_2.sh" ]; then
    MONITOR_SCRIPT="$SCRIPT_DIR/monitor_PPID2407_2.sh"
fi

# --- Run with or without monitoring ---
if [ -n "$MONITOR_SCRIPT" ]; then
    log "Running NOVOPlasty with resource monitoring (script: $MONITOR_SCRIPT)"
    "$MONITOR_SCRIPT" "$NOVOPLASTY_CMD" "${papka_name}_use_res_Novoplasty.csv"
    MONITOR_EXIT=$?
else
    log "Warning: monitoring script not found. Running without monitoring."
    eval "$NOVOPLASTY_CMD"
    MONITOR_EXIT=$?
fi

# --- Process the result ---
if [ $MONITOR_EXIT -eq 0 ]; then
    log "NOVOPlasty finished successfully."
else
    error "NOVOPlasty exited with code $MONITOR_EXIT"
    if [ -f "NOVOPlasty.log" ]; then
        log "Last lines of NOVOPlasty.log:"
        tail -n 10 NOVOPlasty.log | while IFS= read -r line; do log "  $line"; done
    fi
fi

exit $MONITOR_EXIT
