#!/usr/bin/env bash
set -e

# Input validation
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <iso_file> <output_img>"
    exit 1
fi

ISO="$1"
USB_IMG="$2"

# Create temporary work directory
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Extracting ISO..."
7z x "$ISO" -o"$work/extract"

echo "Applying overlay..."
cp -r overlay/* "$work/extract/"

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
