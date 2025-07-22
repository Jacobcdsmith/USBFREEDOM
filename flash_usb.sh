#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <image_path> <target_device>"
    exit 1
}

# Require root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

if [[ $# -ne 2 ]]; then
    usage
fi

IMG="$1"
DEV="$2"

if [[ ! -f "$IMG" ]]; then
    echo "Image file not found: $IMG" >&2
    exit 1
fi

if [[ ! -b "$DEV" ]]; then
    echo "Target device not found or not a block device: $DEV" >&2
    exit 1
fi

read -r -p "All data on $DEV will be overwritten. Continue? [y/N] " ans
case $ans in
    y|Y) ;;
    *) echo "Aborted."; exit 1;;
esac

# Attempt to unmount any mounted partitions
if mount | grep -q "$DEV"; then
    echo "Unmounting $DEV partitions..."
    umount ${DEV}?* || true
fi

sync

echo "Flashing $IMG to $DEV..."
if [[ $(uname) == "Darwin" ]]; then
    dd if="$IMG" of="$DEV" bs=1m status=progress conv=sync
else
    dd if="$IMG" of="$DEV" bs=4M status=progress conv=fsync
fi

sync
echo "Done."
