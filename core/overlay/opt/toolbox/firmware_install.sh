#!/usr/bin/env bash
# Firmware Analysis Toolkit installer

set -e

echo "=================================================="
echo "   USBFREEDOM Firmware Analysis Toolkit Setup"
echo "=================================================="
echo

# Function to check internet connectivity
check_internet() {
    echo "[+] Checking Internet connectivity..."
    if ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo "[+] Internet connection detected."
        return 0
    else
        echo "[-] No Internet connection. Please connect and try again."
        return 1
    fi
}

# Function to install system dependencies
install_system_deps() {
    echo "[+] Installing system dependencies..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y python3-pip git binwalk foremost hexedit xxd >/dev/null 2>&1
    sudo apt-get install -y build-essential zlib1g-dev liblzma-dev >/dev/null 2>&1
    sudo apt-get install -y squashfs-tools gzip unzip p7zip-full >/dev/null 2>&1
    sudo apt-get install -y mtd-utils genisoimage >/dev/null 2>&1
    echo "[+] System dependencies installed"
}

# Function to install analysis tools
install_analysis_tools() {
    echo "[+] Installing firmware analysis tools..."
    
    # Install Python tools
    pip3 install --user binwalk python-magic pycrypto >/dev/null 2>&1
    
    # Install additional utilities
    sudo apt-get install -y firmware-mod-kit cramfsprogs cramfsswap >/dev/null 2>&1 || true
    
    echo "[+] Analysis tools installed"
}

# Function to setup Ghidra
setup_ghidra() {
    echo "[+] Setting up Ghidra..."
    
    mkdir -p ~/firmware-analysis/tools
    cd ~/firmware-analysis/tools
    
    # Download Ghidra if not present
    if [ ! -d "ghidra_*" ]; then
        echo "  Downloading Ghidra..."
        wget -q https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0.3_build/ghidra_11.0.3_PUBLIC_20240410.zip
        unzip -q ghidra_11.0.3_PUBLIC_20240410.zip
        rm ghidra_11.0.3_PUBLIC_20240410.zip
    fi
    
    # Create launcher
    cat > ~/firmware-analysis/tools/ghidra-launcher.sh << 'EOF'
#!/bin/bash
cd ~/firmware-analysis/tools/ghidra_*
./ghidraRun
EOF
    chmod +x ~/firmware-analysis/tools/ghidra-launcher.sh
    
    echo "[+] Ghidra installed"
}

# Function to setup firmwalker
setup_firmwalker() {
    echo "[+] Setting up Firmwalker..."
    
    cd ~/firmware-analysis/tools
    
    if [ ! -d "firmwalker" ]; then
        git clone https://github.com/craigz28/firmwalker.git >/dev/null 2>&1
        chmod +x firmwalker/firmwalker.sh
    fi
    
    echo "[+] Firmwalker installed"
}

# Function to install firmware extraction utilities
install_extraction_utils() {
    echo "[+] Installing firmware extraction utilities..."
    
    # Install jefferson for JFFS2
    pip3 install --user jefferson >/dev/null 2>&1
    
    # Install ubidump for UBI images
    pip3 install --user ubi_reader >/dev/null 2>&1
    
    # Install sasquatch for squashfs
    cd ~/firmware-analysis/tools
    if [ ! -d "sasquatch" ]; then
        git clone https://github.com/devttys0/sasquatch.git >/dev/null 2>&1
        cd sasquatch
        make >/dev/null 2>&1 || echo "  Note: sasquatch build may have warnings"
        cd ..
    fi
    
    echo "[+] Extraction utilities installed"
}

# Function to create analysis workspace
create_workspace() {
    echo "[+] Creating firmware analysis workspace..."
    
    mkdir -p ~/firmware-analysis/{samples,extracted,reports,tools,scripts}
    
    # Create extraction script
    cat > ~/firmware-analysis/scripts/extract-firmware.sh << 'EOF'
#!/bin/bash
# Firmware extraction automation script

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <firmware_file>"
    exit 1
fi

FIRMWARE="$1"
BASENAME=$(basename "$FIRMWARE" .bin)
WORKDIR="~/firmware-analysis/extracted/$BASENAME"

echo "=== Firmware Extraction Report ==="
echo "Firmware: $FIRMWARE"
echo "Output: $WORKDIR"
echo "Date: $(date)"
echo

# Create work directory
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Copy firmware
cp "$FIRMWARE" ./firmware.bin

echo "=== File Information ==="
file firmware.bin
ls -la firmware.bin
echo

echo "=== Binwalk Analysis ==="
binwalk firmware.bin
echo

echo "=== Strings Analysis ==="
strings firmware.bin | head -100 > strings.txt
echo "Strings saved to strings.txt (first 100 lines shown):"
head -20 strings.txt
echo

echo "=== Entropy Analysis ==="
binwalk -E firmware.bin
echo

echo "=== Extraction Attempt ==="
binwalk -e firmware.bin
echo

echo "=== Results ==="
if [ -d "_firmware.bin.extracted" ]; then
    echo "Extraction successful!"
    echo "Extracted files:"
    find _firmware.bin.extracted -type f | head -20
    
    # Run firmwalker if available
    if [ -f ~/firmware-analysis/tools/firmwalker/firmwalker.sh ]; then
        echo
        echo "=== Running Firmwalker ==="
        bash ~/firmware-analysis/tools/firmwalker/firmwalker.sh _firmware.bin.extracted
    fi
else
    echo "No extraction performed - manual analysis may be required"
fi

echo
echo "Analysis complete. Results saved in: $WORKDIR"
EOF

    chmod +x ~/firmware-analysis/scripts/extract-firmware.sh
    
    # Create hex analysis script
    cat > ~/firmware-analysis/scripts/hex-analysis.sh << 'EOF'
#!/bin/bash
# Quick hex analysis of firmware

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <firmware_file>"
    exit 1
fi

FIRMWARE="$1"

echo "=== Hex Analysis: $FIRMWARE ==="
echo

echo "File header (first 256 bytes):"
xxd "$FIRMWARE" | head -16
echo

echo "File trailer (last 256 bytes):"
tail -c 256 "$FIRMWARE" | xxd
echo

echo "Magic signatures found:"
binwalk -B "$FIRMWARE" | head -20
EOF

    chmod +x ~/firmware-analysis/scripts/hex-analysis.sh
    
    echo "[+] Analysis workspace created"
}

# Function to show completion message
show_completion() {
    echo
    echo "=================================================="
    echo "   Firmware Analysis Toolkit Setup Complete!"
    echo "=================================================="
    echo
    echo "Installed tools:"
    echo "  • Binwalk - firmware analysis and extraction"
    echo "  • Ghidra - reverse engineering platform"
    echo "  • Firmwalker - firmware security analysis"
    echo "  • Jefferson - JFFS2 filesystem extraction"
    echo "  • UBI Reader - UBI filesystem extraction"
    echo "  • Sasquatch - enhanced squashfs extraction"
    echo
    echo "Analysis workspace: ~/firmware-analysis/"
    echo
    echo "Quick start commands:"
    echo "  ~/firmware-analysis/tools/ghidra-launcher.sh     # Launch Ghidra"
    echo "  ~/firmware-analysis/scripts/extract-firmware.sh firmware.bin  # Extract firmware"
    echo "  ~/firmware-analysis/scripts/hex-analysis.sh firmware.bin      # Hex analysis"
    echo "  binwalk -e firmware.bin                          # Extract with binwalk"
    echo "  hexedit firmware.bin                             # Hex editor"
    echo
    echo "Analysis workflow:"
    echo "  1. Place firmware in ~/firmware-analysis/samples/"
    echo "  2. Run extraction script for automated analysis"
    echo "  3. Use Ghidra for detailed reverse engineering"
    echo "  4. Check extracted files with firmwalker"
    echo
    echo "⚠️  Only analyze firmware you have permission to examine"
    echo
}

# Main execution
main() {
    if ! check_internet; then
        exit 1
    fi
    
    install_system_deps
    install_analysis_tools
    setup_ghidra
    setup_firmwalker
    install_extraction_utils
    create_workspace
    show_completion
}

# Run main function
main "$@"
