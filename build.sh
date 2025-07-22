#!/usr/bin/env bash
set -e

# Input validation
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <iso_file> <output_img> [overlay_dir]"
    exit 1
fi

ISO="$1"
USB_IMG="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OVERLAY="$SCRIPT_DIR/core/overlay"
OVERLAY_DIR="${3:-${OVERLAY_DIR:-$DEFAULT_OVERLAY}}"

if [ ! -d "$OVERLAY_DIR" ]; then
    echo "Overlay directory '$OVERLAY_DIR' not found" >&2
    exit 1
fi

# Create temporary work directory
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Extracting ISO..."
7z x "$ISO" -o"$work/extract"

echo "Applying overlay from $OVERLAY_DIR..."
cp -r "$OVERLAY_DIR"/* "$work/extract/"

echo "Creating bootable image..."
mkisofs -o "$USB_IMG" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -R -J -v -T \
    "$work/extract"

echo "Image created successfully: $USB_IMG"
