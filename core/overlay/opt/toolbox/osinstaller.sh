#!/usr/bin/env bash
# OS Installation Media (Ventoy Multiboot) manager

set -e

echo "=================================================="
echo "   USBFREEDOM OS Installation Media Manager"
echo "=================================================="
echo

# Function to check if running from Ventoy
check_ventoy_environment() {
    if [ -d "/ventoy" ] || [ -f "/usr/share/ventoy/ventoy.json" ]; then
        return 0
    else
        return 1
    fi
}

# Function to list available ISO files
list_available_isos() {
    echo "[+] Available OS Installation Images:"
    echo
    
    local iso_dirs=("/iso" "/images" "/ventoy" "/media" "/mnt")
    local found_isos=0
    
    for dir in "${iso_dirs[@]}"; do
        if [ -d "$dir" ]; then
            for iso in "$dir"/*.iso "$dir"/*.img; do
                if [ -f "$iso" ]; then
                    local size=$(du -h "$iso" | cut -f1)
                    local name=$(basename "$iso")
                    echo "  • $name ($size)"
                    found_isos=$((found_isos + 1))
                fi
            done
        fi
    done
    
    if [ $found_isos -eq 0 ]; then
        echo "  No ISO files found in standard locations"
        echo "  You may need to copy ISO files to this USB drive"
    fi
    
    echo
}

# Function to show Ventoy management options
show_ventoy_options() {
    echo "[+] Ventoy Management Options:"
    echo
    echo "1) List available OS images"
    echo "2) Boot menu information"
    echo "3) Ventoy configuration"
    echo "4) Check Ventoy version"
    echo "5) Exit"
    echo
}

# Function to show boot menu info
show_boot_info() {
    echo "=================================================="
    echo "   Boot Menu Information"
    echo "=================================================="
    echo
    echo "To boot an OS installer:"
    echo "1. Reboot this system"
    echo "2. Boot from this USB drive"
    echo "3. Select the desired OS from the Ventoy menu"
    echo
    echo "Supported formats:"
    echo "  • ISO files (most Linux distributions)"
    echo "  • IMG files (disk images)"
    echo "  • VHD files (Virtual Hard Disk)"
    echo "  • WIM files (Windows Imaging)"
    echo
    echo "Common OS types available:"
    echo "  • Linux distributions (Ubuntu, Fedora, etc.)"
    echo "  • Windows installation media"
    echo "  • Server operating systems"
    echo "  • Rescue and recovery tools"
    echo
}

# Function to show Ventoy configuration
show_ventoy_config() {
    echo "=================================================="
    echo "   Ventoy Configuration"
    echo "=================================================="
    echo
    
    # Look for ventoy configuration
    local config_files=("/ventoy/ventoy.json" "/usr/share/ventoy/ventoy.json" "/etc/ventoy.json")
    local found_config=0
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            echo "Configuration file: $config"
            echo "Contents:"
            cat "$config" 2>/dev/null || echo "  Could not read configuration"
            found_config=1
            break
        fi
    done
    
    if [ $found_config -eq 0 ]; then
        echo "No Ventoy configuration file found."
        echo "Default configuration is being used."
    fi
    
    echo
}

# Function to check Ventoy version
check_ventoy_version() {
    echo "=================================================="
    echo "   Ventoy Version Information"
    echo "=================================================="
    echo
    
    # Try different methods to get Ventoy version
    if command -v ventoy >/dev/null 2>&1; then
        ventoy --version 2>/dev/null || echo "Ventoy command available but version not accessible"
    elif [ -f "/ventoy/version" ]; then
        echo "Ventoy version: $(cat /ventoy/version)"
    elif [ -f "/usr/share/ventoy/version" ]; then
        echo "Ventoy version: $(cat /usr/share/ventoy/version)"
    else
        echo "Ventoy version information not available"
        echo "This may be a standard USBFREEDOM image rather than Ventoy"
    fi
    
    echo
}

# Function to create OS management workspace
create_os_workspace() {
    echo "[+] Creating OS management workspace..."
    
    mkdir -p ~/os-installer/{isos,tools,docs}
    
    # Create ISO validation script
    cat > ~/os-installer/tools/validate-iso.sh << 'EOF'
#!/bin/bash
# ISO file validation script

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <iso_file>"
    exit 1
fi

ISO="$1"

if [ ! -f "$ISO" ]; then
    echo "Error: ISO file not found: $ISO"
    exit 1
fi

echo "=== ISO Validation Report ==="
echo "File: $ISO"
echo "Date: $(date)"
echo

echo "=== File Information ==="
ls -la "$ISO"
file "$ISO"
echo

echo "=== Checksum ==="
echo "MD5:    $(md5sum "$ISO" | cut -d' ' -f1)"
echo "SHA1:   $(sha1sum "$ISO" | cut -d' ' -f1)"
echo "SHA256: $(sha256sum "$ISO" | cut -d' ' -f1)"
echo

echo "=== ISO Contents ==="
if command -v isoinfo >/dev/null 2>&1; then
    isoinfo -l -i "$ISO" | head -20
else
    echo "isoinfo not available - install genisoimage for detailed analysis"
fi

echo
echo "Validation complete."
EOF

    chmod +x ~/os-installer/tools/validate-iso.sh
    
    # Create documentation
    cat > ~/os-installer/docs/usage.md << 'EOF'
# OS Installation Media Usage Guide

## Adding New ISOs

1. Copy ISO files to the USB drive root directory or `/iso/` folder
2. Reboot and select from Ventoy menu

## Supported Formats

- `.iso` - Standard ISO 9660 images
- `.img` - Raw disk images  
- `.vhd` - Virtual Hard Disk format
- `.wim` - Windows Imaging format

## Ventoy Features

- Secure Boot support
- Persistence for live OSes
- Windows to Go support
- Custom themes and plugins

## Troubleshooting

- If ISO doesn't boot, verify it's not corrupted
- Some ISOs may need specific Ventoy plugins
- Check Ventoy compatibility list online

## Verification

Use the validation script to check ISO integrity:
```bash
~/os-installer/tools/validate-iso.sh /path/to/image.iso
```
EOF

    echo "[+] OS workspace created"
}

# Main interactive loop
main_loop() {
    while true; do
        show_ventoy_options
        read -p "Enter your choice (1-5): " choice
        echo
        
        case $choice in
            1)
                list_available_isos
                ;;
            2)
                show_boot_info
                ;;
            3)
                show_ventoy_config
                ;;
            4)
                check_ventoy_version
                ;;
            5)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select 1-5."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        echo
    done
}

# Main execution
main() {
    if check_ventoy_environment; then
        echo "[+] Ventoy environment detected"
    else
        echo "[!] This appears to be a standard USBFREEDOM image"
        echo "    Some Ventoy-specific features may not be available"
    fi
    
    echo
    create_os_workspace
    main_loop
}

# Run main function
main "$@"
