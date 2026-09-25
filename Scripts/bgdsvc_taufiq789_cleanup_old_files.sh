#!/bin/bash
SVC_NAME="bgdsvc_taufiq789"
TMPDIR="/mnt/${SVC_NAME}_tmp"
LOGFILE="/var/log/bgdsvc_taufiq789/monitor.log"

find "$TMPDIR" -type f -mtime +1 -delete
echo "$(date): cleanup run — removed files older than 1 day from $TMPDIR" >> "$LOGFILE"
