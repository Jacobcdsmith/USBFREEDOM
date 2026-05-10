#!/bin/bash
# USBFREEDOM Persistence Backup Tool
# Creates a backup of persistence data

set -e

PERSIST_MOUNT="/persistence"
BACKUP_DIR="/tmp/persistence-backup-$(date +%Y%m%d-%H%M%S)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Check if persistence is mounted
if ! mountpoint -q "$PERSIST_MOUNT"; then
    error "Persistence is not mounted. Run enable-persistence.sh first"
    exit 1
fi

# Allow custom backup location
if [[ -n "$1" ]]; then
    BACKUP_DIR="$1"
fi

log "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup important directories
log "Backing up persistence data..."
rsync -av --exclude='work/*' "$PERSIST_MOUNT/" "$BACKUP_DIR/"

log "Backup completed successfully"
log "Backup location: $BACKUP_DIR"
log "Size: $(du -sh "$BACKUP_DIR" | cut -f1)"

exit 0
