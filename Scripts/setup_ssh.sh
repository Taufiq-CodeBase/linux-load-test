#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

KEY_PATH="$HOME/.ssh/${SVC_NAME}_key"
USER_SSH_DIR="/home/${SVC_NAME}/.ssh"
AUTH_KEYS="${USER_SSH_DIR}/authorized_keys"

echo "=== [1/3] Generating SSH Key Pair ==="
if [ -f "$KEY_PATH" ]; then
    echo "Key pair already exists at $KEY_PATH. Skipping generation."
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N ""
fi

echo "=== [2/3] Configuring Authorized Keys & Permissions ==="
sudo mkdir -p "$USER_SSH_DIR"
sudo cp "${KEY_PATH}.pub" "$AUTH_KEYS"

# Apply restrictive security boundaries
sudo chown -R "${SVC_NAME}:${SVC_NAME}" "$USER_SSH_DIR"
sudo chmod 700 "$USER_SSH_DIR"
sudo chmod 600 "$AUTH_KEYS"

echo "=== [3/3] Guaranteeing Local SSH Server Deployment ==="
if ! systemctl is-active --quiet ssh; then
    echo "Installing and starting OpenSSH server..."
    sudo apt update && sudo apt install openssh-server -y
    sudo systemctl enable --now ssh
else
    echo "SSH service is already running."
fi

echo "Configuration deployment finished."
echo "Execute the test handshake via:"
echo "ssh -i $KEY_PATH ${SVC_NAME}@localhost"
