#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

MOUNT_DIR="/mnt/${SVC_NAME}_tmp"

# Create the directory if it does not exist
if [ ! -d "$MOUNT_DIR" ]; then
    echo "Creating directory $MOUNT_DIR..."
    sudo mkdir -p "$MOUNT_DIR"
fi

# Check if already mounted to avoid duplicate mounts
if mountpoint -q "$MOUNT_DIR"; then
    echo "$MOUNT_DIR is already mounted. Skipping mount step."
else
    echo "Mounting tmpfs to $MOUNT_DIR..."
    sudo mount -t tmpfs -o size=256M tmpfs "$MOUNT_DIR"
fi

# Set proper ownership for the service account
echo "Setting ownership to $SVC_NAME..."
sudo chown "$SVC_NAME:$SVC_NAME" "$MOUNT_DIR"

# Verify the mount status
df -h "$MOUNT_DIR"
