#!/usr/bin/env bash
# integration_test.sh - Test the complete USBFREEDOM build process

set -e

echo "USBFREEDOM Integration Test"
echo "=========================="

# Create a minimal test ISO
echo "Creating test ISO..."
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/test_iso/isolinux"
touch "$TEST_DIR/test_iso/isolinux/isolinux.bin"
touch "$TEST_DIR/test_iso/isolinux/boot.cat"

cd "$TEST_DIR"
mkisofs -o test.iso \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -R -J -v -T \
    test_iso/ 2>/dev/null

echo "Testing build script..."
cd /home/runner/work/USBFREEDOM/USBFREEDOM

# Test the build process
if ./build.sh "$TEST_DIR/test.iso" "$TEST_DIR/test-output.img"; then
    echo "✓ Build script executed successfully"
    
    if [ -f "$TEST_DIR/test-output.img" ]; then
        echo "✓ Output image was created"
        echo "✓ Integration test PASSED"
    else
        echo "✗ Output image was not created"
        exit 1
    fi
else
    echo "✗ Build script failed"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"
echo "✓ Cleanup completed"