#!/bin/bash

#Checking arguments
if [ "$#" -ne 2 ]; then
    echo "Using: $0 <data_file> <script_assembler>"
    exit 1
fi

data_file="$1"
script_assembler="$2"

#Path configuration
LOG_FILE="script_$(date +'%Y-%m-%d_%H-%M-%S').log"
ERROR_LOG_FILE="errors_$(date +'%Y-%m-%d_%H-%M-%S').log"

#Logging functions
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

error_log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] ERROR: $1" | tee -a "$ERROR_LOG_FILE" >&2
}

#Redirecting error output
exec 2> >(tee -a "$ERROR_LOG_FILE")

#Log header
log "Running the script ${0##*/}"
log "Current directory: $(pwd)"
log "Logging to a file: $LOG_FILE"
log "----------------------------------------"

#Checking the existence of a file
if ! test -f "$data_file"; then
    error_log "File $data_file not found!"
    exit 1
fi

#Checking the existence and execution rights of script_assembler
if ! test -x "$script_assembler"; then
    error_log "The script $script_assembler does not exist or is not executable!"
    exit 1
fi

#The main processing cycle
line_number=0
error_count=0

while IFS= read -r line || [ -n "$line" ]; do
    ((line_number++))

    log "String processing $line_number: [$line]"

    #Clearing a row
    line_clean="${line%%#*}"
    line_clean="${line_clean##*( )}"

    #Skipping empty lines
    if [ -z "$line_clean" ]; then
        log "Empty line  - skip"
        continue
    fi

    #Parsing the arguments
    read -ra args <<< "$line_clean"
    log "Arguments found: ${#args[@]}"
    log "Details of the arguments: ${args[*]}"

    #Executing a command with logging
    log "Running: ${script_assembler} ${args[*]}"
    start_time=$(date +%s)

    if ! "$script_assembler" "${args[@]}" >> "$LOG_FILE" 2>&1; then
        error_log "Line $line_number: Command execution error (code $?)"
        error_log "The original line: $line"
        error_log "Arguments: ${args[*]}"
        ((error_count++))
    else
        #Calculation of the execution time
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "Completed successfully in ${duration} seconds"
    fi

    log "----------------------------------------"

done < "$data_file"

#Finalizing
log "Rows processed: $line_number"
log "Number of errors: $error_count"
log "The script has completed its work successfully"
exit 0

