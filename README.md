# USBFREEDOM

Collection of preloaded USB toolkit images for various cybersecurity, development, and system administration tasks.

## Available Toolkits

1. **Penetration Testing Kit** (Kali-based)
   - Offensive security toolkit with Metasploit, Nmap, BloodHound, and ffuf
   - Features CTF-style unlock portal

2. **Malware Analysis Lab** (REMnux-based)
   - Includes IDA Free, CAPE sandbox, and custom Ghidra scripts
   - Auto-starts CAPE web UI via systemd

3. **Data Science Workbench** (Ubuntu LTS)
   - Full conda environment with JupyterLab
   - Includes DuckDB and Apache Spark
   - Pre-loaded example notebooks and datasets

4. **Mobile Development SDK** (Manjaro ARM)
   - Complete Flutter and Android SDK setup
   - VS Code devcontainer configuration
   - Preconfigured udev rules for Android devices

5. **SDR Communications Kit** (Kali-SDR)
   - GNURadio, gqrx, SigDigger
   - HackRF and RTL-SDR tools
   - Example flow-graphs included

6. **Firmware Analysis Toolkit** (Debian)
   - Ghidra, binwalk, Firmwalker
   - JFFS2 extraction tools
   - OpenOCD configuration
   - Auto flash extraction script

7. **ICS/SCADA Security Suite** (Kali ICS)
   - Modbus/TCP fuzzing tools
   - Wireshark with PLC plugins
   - PLCSim for testing
   - Isolated lab environment

8. **OS Installation Media**
   - Ventoy-based multiboot setup
   - Windows 10/11 Evaluation
   - Server OSes (Windows Server, ESXi, Proxmox)
   - Network appliances (TrueNAS, pfSense)
   - Linux distributions

## Building Images

```bash
# Build a single image
./build.sh base_iso/kali-linux-rolling.iso pentest-kit.img

# Build all images via GitHub Actions
git push origin main
```

## Project Structure

```
core/
  ├── base_iso/     # Base distribution ISOs
  └── overlay/      # Common configuration files
build.sh            # ISO patching script
ventoy.json        # Boot menu configuration
.github/workflows/  # CI/CD configuration
```

## CI/CD Pipeline

- GitHub Actions automatically builds all toolkit images
- Tagged releases are uploaded to S3
- Checksum verification included

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## License

See LICENSE file for details.
