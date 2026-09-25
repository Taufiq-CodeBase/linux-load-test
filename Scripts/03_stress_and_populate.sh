#!/bin/bash

# Ensure the SVC_NAME environment variable is set
if [ -z "$SVC_NAME" ]; then
    echo "Error: SVC_NAME environment variable is not set."
    exit 1
fi

MOUNT_DIR="/mnt/${SVC_NAME}_tmp"

# Ensure stress-ng is installed
if ! command -v stress-ng &>/dev/null; then
    echo "Installing stress-ng..."
    sudo apt update && sudo apt install stress-ng -y
fi

# Define test functions
stress_disk() {
    echo "Starting disk stress test (filling tmpfs)..."
    for i in $(seq 1 20); do
        dd if=/dev/urandom of="${MOUNT_DIR}/file_$i.dat" bs=1M count=10 2>/dev/null
        df -h "$MOUNT_DIR"
    done
}

stress_cpu() {
    echo "Starting CPU stress test (30s)..."
    sudo -u "$SVC_NAME" stress-ng --cpu 2 --timeout 30s
}

stress_mem() {
    echo "Starting memory stress test (30s)..."
    sudo -u "$SVC_NAME" stress-ng --vm 1 --vm-bytes 200M --timeout 30s
}

# Parse command line flags
RUN_CPU=false
RUN_MEM=false
RUN_DISK=false
RUN_ALL=false

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [--cpu] [--mem] [--disk] [--all]"
    exit 1
fi

for arg in "$@"; do
    case $arg in
        --cpu)  RUN_CPU=true ;;
        --mem)  RUN_MEM=true ;;
        --disk) RUN_DISK=true ;;
        --all)  RUN_ALL=true ;;
        *)
            echo "Unknown flag: $arg"
            exit 1
            ;;
    esac
done

# Run tests based on selected flags
if [ "$RUN_ALL" = true ]; then
    echo "Running all stress tests concurrently..."
    stress_disk &
    stress_cpu &
    stress_mem &
    wait
    echo "All concurrent stress tests completed."
else
    if [ "$RUN_DISK" = true ]; then stress_disk; fi
    if [ "$RUN_CPU" = true ]; then stress_cpu; fi
    if [ "$RUN_MEM" = true ]; then stress_mem; fi
fi
