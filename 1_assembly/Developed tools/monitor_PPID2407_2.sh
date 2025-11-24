#!/bin/bash
# monitor_script.sh

#Checking arguments
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
 echo "Usage: $0 <target_script> [output_csv]"
 echo "Example: $0 ./my_app.sh memory_report.csv"
 exit 1
fi

TARGET_SCRIPT=$1
LOG_FILE="${2:-resource_usage.csv}" # By default: resource_usage.csv
INTERVAL=1

#Creating a CSV file header
echo "timestamp,pid,ppid,user,%cpu,%mem,rss_mb,vsz_mb,command" > "$LOG_FILE"

#Running the target script
$TARGET_SCRIPT &
MAIN_PID=$!

#Monitoring function
monitor_processes() {
 while true; do
 #We get all child processes
 pstree -p $MAIN_PID | grep -oP '\d+(?=\))' | while read -r pid; do
 #We collect data converted to MB
 ps -p $pid -o pid=,ppid=,user=,%cpu=,%mem=,rss=,vsz=,comm= --no-headers | \
 awk -v date="$(date +"%Y-%m-%d %T")" \
 '{printf "%s,%d,%d,%s,%.1f,%.1f,%.2f,%.2f,%s\n", 
 date, $1, $2, $3, $4, $5, $6/1024, $7/1024, $8}' >> "$LOG_FILE"
 done
 sleep $INTERVAL
 done
}

#Running monitoring
monitor_processes &
MONITOR_PID=$!

#Waiting for completion
wait $MAIN_PID

#Stopping monitoring
kill $MONITOR_PID
echo "Monitoring is completed. Report: $LOG_FILE"

