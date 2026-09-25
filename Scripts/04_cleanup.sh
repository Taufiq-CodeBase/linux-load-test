#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

MOUNT_DIR="/mnt/${SVC_NAME}_tmp"
LOG_DIR="/var/log/${SVC_NAME}"
LOGROTATE_CONF="/etc/logrotate.d/${SVC_NAME}"
MONITOR_SCRIPT="/usr/local/bin/${SVC_NAME}_monitor.sh"
CLEANUP_SCRIPT="/usr/local/bin/${SVC_NAME}_cleanup_old_files.sh"

echo "=== [1/5] Terminating User Background Processes ==="
if id "$SVC_NAME" &>/dev/null; then
    echo "Killing all running processes owned by $SVC_NAME..."
    sudo pkill -u "$SVC_NAME"
    sleep 1
else
    echo "User $SVC_NAME does not exist. Skipping process kill step."
fi

echo "=== [2/5] Removing Automation Schedules & Configurations ==="
if id "$SVC_NAME" &>/dev/null; then
    echo "Clearing crontab profile..."
    sudo crontab -r -u "$SVC_NAME" 2>/dev/null
fi

echo "Removing script hooks and logrotate rules..."
sudo rm -f "$LOGROTATE_CONF"
sudo rm -f "$MONITOR_SCRIPT"
sudo rm -f "$CLEANUP_SCRIPT"

echo "=== [3/5] Cleaning Storage Mount Points ==="
if mountpoint -q "$MOUNT_DIR"; then
    echo "Unmounting tmpfs scratch area at $MOUNT_DIR..."
    sudo umount "$MOUNT_DIR"
else
    echo "Directory $MOUNT_DIR is not mounted. Skipping unmount step."
fi

if [ -d "$MOUNT_DIR" ]; then
    echo "Removing temporary directory structure..."
    sudo rmdir "$MOUNT_DIR"
fi

echo "=== [4/5] Wiping Environment Log Records ==="
if [ -d "$LOG_DIR" ]; then
    echo "Purging log path at $LOG_DIR..."
    sudo rm -rf "$LOG_DIR"
fi

echo "=== [5/5] Deleting Identity Account ==="
if id "$SVC_NAME" &>/dev/null; then
    echo "Removing user profile and home directory matching $SVC_NAME..."
    sudo userdel -r "$SVC_NAME" 2>/dev/null
else
    echo "User $SVC_NAME already completely removed."
fi

echo "=== Verification Checks ==="
echo "1. Account verification (should return an error):"
id "$SVC_NAME"

echo "2. Active mount registry (should return empty output):"
mount | grep "$SVC_NAME"

echo "3. Active task list (should return empty headers):"
ps -u "$SVC_NAME" 2>/dev/null
