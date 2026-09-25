#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%F_%T)"

echo "=== [1/4] Creating Configuration Backup ==="
sudo cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"

echo "=== [2/4] Modifying SSH Configuration Parameters ==="
# Strip existing lines if they exist to prevent duplicates
sudo sed -i '/^Port /d' "$CONFIG_FILE"
sudo sed -i '/^PermitRootLogin/d' "$CONFIG_FILE"
sudo sed -i '/^PasswordAuthentication/d' "$CONFIG_FILE"
sudo sed -i '/^AllowUsers/d' "$CONFIG_FILE"

# Append the hardening policies (Includes your active 'ubuntu' user)
sudo tee -a "$CONFIG_FILE" > /dev/null <<EOT

# Hardened Policy Config
Port 2222
PermitRootLogin no
PasswordAuthentication no
AllowUsers ubuntu $SVC_NAME
EOT

echo "=== [3/4] Testing SSH Config Syntax ==="
if ! sudo sshd -t; then
    echo "CRITICAL ERROR: Syntax check failed! Reverting to backup immediately..."
    sudo cp "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi
echo "Configuration syntax is valid."

echo "=== [4/4] Restarting SSH Daemon ==="
sudo systemctl restart ssh
echo "SSH Daemon successfully reloaded on port 2222."
