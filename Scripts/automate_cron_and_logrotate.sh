#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

MONITOR_SCRIPT="/usr/local/bin/${SVC_NAME}_monitor.sh"
CLEANUP_SCRIPT="/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh"
LOG_DIR="/var/log/${SVC_NAME}"
LOGROTATE_CONF="/etc/logrotate.d/${SVC_NAME}"

echo "=== [1/5] Preparing Log Directories and Permissions ==="
sudo mkdir -p "$LOG_DIR"
sudo chown -R "$SVC_NAME:$SVC_NAME" "$LOG_DIR"

echo "=== [2/5] Generating Monitoring and Cleanup Scripts ==="
sudo tee "$MONITOR_SCRIPT" > /dev/null <<EOT
#!/bin/bash
SVC_NAME="$SVC_NAME"
LOGFILE="$LOG_DIR/monitor.log"
echo "--- \$(date) ---" >> "\$LOGFILE"
free -h >> "\$LOGFILE"
df -h "/mnt/\${SVC_NAME}_tmp" >> "\$LOGFILE" 2>&1
ps -u "\$SVC_NAME" >> "\$LOGFILE" 2>&1
EOT

sudo tee "$CLEANUP_SCRIPT" > /dev/null <<EOT
#!/bin/bash
SVC_NAME="$SVC_NAME"
TMPDIR="/mnt/\${SVC_NAME}_tmp"
LOGFILE="$LOG_DIR/monitor.log"

find "\$TMPDIR" -type f -mtime +1 -delete
echo "\$(date): cleanup run — removed files older than 1 day from \$TMPDIR" >> "\$LOGFILE"
EOT

sudo chmod +x "$MONITOR_SCRIPT" "$CLEANUP_SCRIPT"

echo "=== [3/5] Injecting Cron Tasks to Service User ==="
CRON_1="*/5 * * * * $MONITOR_SCRIPT"
CRON_2="0 2 * * * $CLEANUP_SCRIPT"
(sudo crontab -u "$SVC_NAME" -l 2>/dev/null; echo "$CRON_1"; echo "$CRON_2") | sudo crontab -u "$SVC_NAME" -

echo "=== [4/5] Deploying Logrotate Rules ==="
# Dynamically writes your literal chosen service name into the rule template
sudo tee "$LOGROTATE_CONF" > /dev/null <<EOT
$LOG_DIR/*.log {
    daily
    rotate 5
    compress
    missingok
    notifempty
    size 10M
    create 0640 $SVC_NAME $SVC_NAME
}
EOT

echo "=== [5/5] Testing and Validating Logrotate Rule ==="
# Force an initial execution loop to ensure parsing is correct
sudo logrotate -f "$LOGROTATE_CONF"
ls -lh "$LOG_DIR/"
