#!/bin/bash
SVC_NAME="bgdsvc_taufiq789"
LOGFILE="/var/log/bgdsvc_taufiq789/monitor.log"
echo "--- $(date) ---" >> "$LOGFILE"
free -h >> "$LOGFILE"
df -h "/mnt/${SVC_NAME}_tmp" >> "$LOGFILE" 2>&1
ps -u "$SVC_NAME" >> "$LOGFILE" 2>&1
