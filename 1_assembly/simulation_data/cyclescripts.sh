#!/bin/bash
set -uo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <config_file> <universal_script> <assembler_name>"
    echo "  assembler_name: ARC, GetOrganelle, MEANGS, MITGARD, MITObim, MitoFinder, MitoZ, NOVOPlasty, Norgal, mtGrasp"
    exit 1
fi

config_file="$1"
universal_script="$2"
assembler_name="$3"

LOG_FILE="script_$(date +'%Y-%m-%d_%H-%M-%S').log"
ERROR_LOG_FILE="errors_$(date +'%Y-%m-%d_%H-%M-%S').log"

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
log "Config: $config_file"
log "Assembler script: $universal_script"
log "Assembler: $assembler_name"
log "----------------------------------------"

# Checking existence and permissions with explicit messages
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

# Determining the key order for each assembler
case "$assembler_name" in
    ARC)            key_order="config name" ;;
    GetOrganelle)   key_order="read1 read2 ref name" ;;
    MEANGS)         key_order="read1 read2 name len_ins" ;;
    MITGARD)        key_order="read1 read2 ref name" ;;
    MITObim)        key_order="reads ref name" ;;
    MitoFinder)     key_order="read1 read2 ref name" ;;
    MitoZ)          key_order="read1 read2 name" ;;
    NOVOPlasty)     key_order="config name" ;;
    Norgal)         key_order="read1 read2 name" ;;
    mtGrasp)        key_order="read1 read2 ref name" ;;
    *)              error_log "Неизвестный сборщик: $assembler_name"; exit 1 ;;
esac

# Convert string to array
key_order_arr=($key_order)

# String parsing function (without associative arrays)
parse_line() {
    local line="$1"
    local -n out_args=$2
    local keys=()
    local vals=()
    out_args=()

    for token in $line; do
        if [[ "$token" =~ ^([a-zA-Z0-9_]+)=(.*)$ ]]; then
            keys+=("${BASH_REMATCH[1]}")
            vals+=("${BASH_REMATCH[2]}")
        else
            error_log "Invalid token: $token"
            return 1
        fi
    done

    for key in "${key_order_arr[@]}"; do
        local found=0
        for i in "${!keys[@]}"; do
            if [[ "${keys[$i]}" == "$key" ]]; then
                out_args+=("${vals[$i]}")
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            error_log "Required key missing '$key'"
            return 1
        fi
    done
    return 0
}

# Main loop
line_number=0
error_count=0

while IFS= read -r line || [ -n "$line" ]; do
    ((line_number++))
    # Remove comment
    line_clean="${line%%#*}"
    # Trim leading and trailing spaces using sed
    line_clean=$(echo "$line_clean" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -z "$line_clean" ] && continue

    log "Processing string $line_number: $line_clean"

    if parse_line "$line_clean" args; then
        log "Arguments: ${args[*]}"
        log "Run: $universal_script ${args[*]}"
        start_time=$(date +%s)
        if "$universal_script" "${args[@]}" >> "$LOG_FILE" 2>&1; then
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            log "Successfully completed in ${duration} sec"
        else
            error_log "String $line_number: execution error (code $?)"
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
