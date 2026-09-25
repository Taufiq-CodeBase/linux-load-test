#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

# Check if the service account already exists
if id "$SVC_NAME" &>/dev/null; then
    echo "User '$SVC_NAME' already exists. Skipping creation."
else
    echo "Creating system user '$SVC_NAME'..."
    sudo useradd -r -m -s /usr/sbin/nologin "$SVC_NAME"
fi

# Verify the user configuration
id "$SVC_NAME"
getent passwd "$SVC_NAME"
