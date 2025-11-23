#!/bin/bash
# USBFREEDOM Persistence Enabler
# This script detects and mounts the persistence partition
# Should be run early in boot or manually to enable persistence

set -e

PERSIST_LABEL="persistence"
PERSIST_MOUNT="/persistence"
LOG_FILE="/var/log/usbfreedom-persistence.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

log "USBFREEDOM Persistence Enabler starting..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Find persistence partition by label
log "Looking for persistence partition with label: $PERSIST_LABEL"
PERSIST_PART=$(findfs LABEL=$PERSIST_LABEL 2>/dev/null || true)

if [[ -z "$PERSIST_PART" ]]; then
    error "No persistence partition found with label '$PERSIST_LABEL'"
    error "Persistence is NOT enabled"
    exit 1
fi

log "Found persistence partition: $PERSIST_PART"

# Create mount point if it doesn't exist
if [[ ! -d "$PERSIST_MOUNT" ]]; then
    log "Creating mount point: $PERSIST_MOUNT"
    mkdir -p "$PERSIST_MOUNT"
fi

# Check if already mounted
if mountpoint -q "$PERSIST_MOUNT"; then
    log "Persistence partition already mounted at $PERSIST_MOUNT"
else
    # Mount the persistence partition
    log "Mounting persistence partition..."
    if mount "$PERSIST_PART" "$PERSIST_MOUNT"; then
        log "Successfully mounted $PERSIST_PART to $PERSIST_MOUNT"
    else
        error "Failed to mount persistence partition"
        exit 1
    fi
fi

# Verify persistence structure
log "Verifying persistence structure..."
if [[ ! -f "$PERSIST_MOUNT/persistence.conf" ]]; then
    error "No persistence.conf found. Persistence structure may be corrupt."
    exit 1
fi

# Check for required directories
for dir in upper work; do
    if [[ ! -d "$PERSIST_MOUNT/$dir" ]]; then
        log "Creating missing directory: $PERSIST_MOUNT/$dir"
        mkdir -p "$PERSIST_MOUNT/$dir"
    fi
done

log "Persistence structure verified"

# Setup overlayfs for each persisted directory
# Note: This is simplified - real live systems use more complex init hooks
log "Persistence partition is ready at $PERSIST_MOUNT"
log "To use overlayfs, add 'persistence' to kernel boot parameters"

# Display status
log "Persistence Status:"
log "  Partition: $PERSIST_PART"
log "  Mount: $PERSIST_MOUNT"
log "  Size: $(df -h $PERSIST_MOUNT | tail -1 | awk '{print $2}')"
log "  Used: $(df -h $PERSIST_MOUNT | tail -1 | awk '{print $3}')"
log "  Available: $(df -h $PERSIST_MOUNT | tail -1 | awk '{print $4}')"

log "Persistence enabled successfully!"
exit 0
