#!/bin/bash
# USBFREEDOM Persistence Disabler
# Safely unmounts persistence partition

set -e

PERSIST_MOUNT="/persistence"
LOG_FILE="/var/log/usbfreedom-persistence.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

log "USBFREEDOM Persistence Disabler starting..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Check if persistence is mounted
if ! mountpoint -q "$PERSIST_MOUNT"; then
    log "Persistence is not currently mounted"
    exit 0
fi

# Sync before unmounting
log "Syncing filesystems..."
sync

# Unmount persistence
log "Unmounting persistence partition..."
if umount "$PERSIST_MOUNT"; then
    log "Persistence disabled successfully"
else
    error "Failed to unmount persistence partition"
    error "You may need to close applications using it first"
    exit 1
fi

log "Persistence disabled"
exit 0
