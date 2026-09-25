#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
SWAP_FILE="/swapfile"
SWAP_SIZE_GB=2

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script as root or with sudo."
  exit 1
fi

# Check if swap already exists
if grep -q "$SWAP_FILE" /proc/swaps; then
  echo "⚠️ Swap file $SWAP_FILE already exists and is active."
  exit 0
fi

echo "🚀 Starting swap file setup (${SWAP_SIZE_GB}GB)..."

# 1. Allocate space for the swap file efficiently
echo "📦 Allocating space..."
fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((SWAP_SIZE_GB * 1024))

# 2. Set strict file permissions (security best practice)
echo "🔒 Setting permissions..."
chmod 600 "$SWAP_FILE"

# 3. Set up the file as Linux swap area
echo "🛠️ Formatting file as swap..."
mkswap "$SWAP_FILE"

# 4. Enable the swap file immediately
echo "🚀 Activating swap..."
swapon "$SWAP_FILE"

# 5. Make the swap file permanent across reboots
if ! grep -q "$SWAP_FILE" /etc/fstab; then
  echo "💾 Making swap permanent across reboots..."
  echo "$SWAP_FILE swap swap defaults 0 0" >> /etc/fstab
fi

# 6. Optimize swappiness (optional but recommended)
# 10 means the system only swaps when RAM is 90% full, preserving performance
echo "⚙️ Tuning swappiness..."
sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
  echo "vm.swappiness=10" >> /etc/sysctl.conf
else
  sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
fi

echo "✅ Swap setup complete!"
echo "📊 Current memory status:"
free -h
