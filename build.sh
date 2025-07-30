#!/usr/bin/env bash
set -e

# Input validation
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <iso_file> <output_img>"
    echo ""
    echo "Example:"
    echo "  $0 base_iso/kali-linux-rolling.iso pentest-kit.img"
    exit 1
fi

ISO="$1"
USB_IMG="$2"

# Validate input file exists
if [ ! -f "$ISO" ]; then
    echo "Error: ISO file '$ISO' does not exist"
    exit 1
fi

# Check required tools
if ! command -v 7z >/dev/null 2>&1; then
    echo "Error: 7z command not found. Please install p7zip-full"
    exit 1
fi

if ! command -v mkisofs >/dev/null 2>&1; then
    echo "Error: mkisofs command not found. Please install genisoimage"
    exit 1
fi

# Check if overlay directory exists
if [ ! -d "core/overlay" ]; then
    echo "Error: core/overlay directory not found"
    exit 1
fi

# Create temporary work directory
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Extracting ISO..."
7z x "$ISO" -o"$work/extract"

echo "Applying overlay..."
cp -r core/overlay/* "$work/extract/"

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
