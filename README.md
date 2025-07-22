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

Once an image is built, use the helper script to write it to a USB drive:

```bash
sudo ./flash_usb.sh <image_file> <device>
```

Example:

```bash
sudo ./flash_usb.sh pentest-kit.img /dev/sdX
```

Replace `/dev/sdX` with your target drive.
