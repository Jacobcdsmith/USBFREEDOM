# USBFREEDOM

A collection of preloaded USB toolkit images designed for various tasks in cybersecurity, development, and system administration.

## Available Toolkits

1. **Penetration Testing Kit** (Kali-based)
   - Offensive security tools like Metasploit, Nmap, BloodHound, and ffuf
   - Includes a CTF-style unlock portal

2. **Malware Analysis Lab** (REMnux-based)
   - Equipped with IDA Free, CAPE sandbox, and custom Ghidra scripts
   - Automatically starts CAPE web UI using systemd

3. **Data Science Workbench** (Ubuntu LTS)
   - Features a full conda environment with JupyterLab
   - Includes DuckDB, Apache Spark, and preloaded example notebooks and datasets

4. **Mobile Development SDK** (Manjaro ARM)
   - Fully configured Flutter and Android SDK setup
   - VS Code devcontainer configuration included
   - Predefined udev rules for Android devices

5. **SDR Communications Kit** (Kali-SDR)
   - Comes with GNURadio, gqrx, SigDigger
   - Includes HackRF and RTL-SDR tools along with example flow-graphs

6. **Firmware Analysis Toolkit** (Debian)
   - Tools like Ghidra, binwalk, Firmwalker
   - JFFS2 extraction utilities
   - OpenOCD configuration and an automated flash extraction script

7. **ICS/SCADA Security Suite** (Kali ICS)
   - Modbus/TCP fuzzing tools, Wireshark with PLC plugins
   - PLCSim for testing in an isolated lab environment

8. **OS Installation Media**
   - Ventoy-based multiboot setup
   - Includes Windows 10/11 Evaluation, server OSes (Windows Server, ESXi, Proxmox), network appliances (TrueNAS, pfSense), and Linux distributions

## Building Images

```bash
# Build a single image
./build.sh base_iso/kali-linux-rolling.iso pentest-kit.img

# Build all images via GitHub Actions
git push origin main
```

## Flashing Images to USB

### Basic Flash (No Persistence)

Use the helper script to write an image to a USB drive:

```bash
sudo ./flash_usb.sh <image_file> <device>
```

Example:

```bash
sudo ./flash_usb.sh pentest-kit.img /dev/sdX
```

### Flash with Persistence ✨ NEW

**Persistence allows your USB drive to save data, configurations, and changes across reboots!**

#### List Available USB Devices

```bash
python3 -m usbfreedom.cli list-devices
```

#### Flash with All Remaining Space for Persistence

```bash
sudo python3 -m usbfreedom.cli flash pentest-kit.img /dev/sdX --persistence
```

#### Flash with Specific Persistence Size

```bash
# Flash with 4GB persistence partition
sudo python3 -m usbfreedom.cli flash pentest-kit.img /dev/sdX --persistence --persistence-size 4096

# Flash with 8GB persistence partition
sudo python3 -m usbfreedom.cli flash pentest-kit.img /dev/sdX --persistence --persistence-size 8192
```

**What gets persisted?**
- User home directories (`/home`)
- System configurations (`/etc`)
- Log files (`/var/log`)
- Root user data (`/root`)
- Local installations (`/usr/local`)

**See [PERSISTENCE.md](PERSISTENCE.md) for complete documentation.**

Replace `/dev/sdX` with your target drive.

## Features

### 🔄 Persistence Support

- **Dual-partition layout**: Bootable system + persistent data partition
- **Configurable size**: Choose how much space to allocate for persistence
- **Automatic setup**: Persistence structure created during flash
- **Boot options**: Choose persistence or fresh state at boot
- **Management tools**: Built-in scripts to manage persistent data

See [PERSISTENCE.md](PERSISTENCE.md) for detailed documentation.

### 🛠️ Toolkit Management

- **Pre-configured toolkits**: 8 specialized kits for different use cases
- **Custom kits**: Build your own with modular package selection
- **Interactive CLI**: User-friendly command-line interface

### 📦 Modular Architecture

- **Category-based**: Tools organized by use case
- **Package modules**: Fine-grained control over installed tools
- **YAML configuration**: Easy to customize and extend

## Command Reference

```bash
# List available toolkits
python3 -m usbfreedom.cli list-toolkits

# List module categories
python3 -m usbfreedom.cli list-categories

# Build a pre-configured toolkit
python3 -m usbfreedom.cli build <toolkit_id> <output_file>

# Build a custom kit interactively
python3 -m usbfreedom.cli build-custom <output_file>

# List USB devices
python3 -m usbfreedom.cli list-devices

# Flash without persistence
python3 -m usbfreedom.cli flash <image> <device>

# Flash with persistence
python3 -m usbfreedom.cli flash <image> <device> --persistence --persistence-size <MB>
```

## Project Structure

```
USBFREEDOM/
├── usbfreedom/              # Python package
│   ├── cli.py              # Command-line interface
│   ├── core.py             # Core builder and flasher classes
│   ├── partition.py        # Partition management
│   ├── persistence.py      # Persistence configuration
│   ├── interactive.py      # Interactive menus
│   └── utils.py            # Utility functions
├── core/overlay/            # Files copied to all images
│   ├── etc/                # Configuration files
│   └── usr/local/bin/      # Utility scripts
│       ├── enable-persistence.sh
│       ├── disable-persistence.sh
│       ├── backup-persistence.sh
│       └── persistence-status.sh
├── tests/                   # Unit tests
├── modules.yaml             # Module definitions
├── toolkits.yaml           # Toolkit configurations
├── build.sh                # Legacy build script
├── flash_usb.sh            # Legacy flash script
├── README.md               # This file
└── PERSISTENCE.md          # Persistence documentation
```
