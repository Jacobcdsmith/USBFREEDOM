# Base ISO Directory

This directory should contain the base ISO files used for building the various toolkit images.

## Usage

Place your base ISO files here before running the build script:

```bash
# Example: Download a Kali Linux ISO
wget -O base_iso/kali-linux-rolling.iso https://cdimage.kali.org/kali-latest/kali-linux-rolling-live-amd64.iso

# Build the pentest toolkit
./build.sh base_iso/kali-linux-rolling.iso pentest-kit.img
```

## Expected ISO Files

The GitHub Actions workflow expects these base ISOs:

- `kali-linux-rolling.iso` - For penetration testing and SDR toolkits
- `remnux-2025.iso` - For malware analysis toolkit  
- `ubuntu-24.04-live-server.iso` - For data science workbench
- `manjaro-arm-minimal.img` - For mobile development SDK
- `debian-12-netinst.iso` - For firmware analysis toolkit
- `kali-linux-rolling-ics.iso` - For ICS/SCADA security suite
- `ventoy-baseline.iso` - For OS installation media

## Note

This directory is included in `.gitignore` since ISO files are large and should not be committed to the repository.