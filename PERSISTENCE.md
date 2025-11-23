# USBFREEDOM Persistence Guide

## Overview

The persistence feature allows USB drives to save data, configurations, and changes across reboots. This is achieved by creating a separate partition on the USB drive that stores persistent data.

## How Persistence Works

### Partition Layout

When persistence is enabled, USBFREEDOM creates a dual-partition layout:

```
┌─────────────────────────────────────────────────┐
│ USB Device                                      │
├─────────────────────────────────────────────────┤
│ Partition 1: Boot (FAT32)                      │
│   - Bootable live system                       │
│   - Read-only base                              │
│   - Label: "USBBOOT"                            │
├─────────────────────────────────────────────────┤
│ Partition 2: Persistence (ext4)                │
│   - User data and changes                       │
│   - Configurations                              │
│   - Label: "persistence"                        │
└─────────────────────────────────────────────────┘
```

### Directory Structure

The persistence partition contains:

```
/persistence/
├── persistence.conf      # Configuration file
├── upper/               # Overlayfs upper directory (changes)
├── work/                # Overlayfs work directory
├── home/                # User home directories
├── root/                # Root user data
├── etc/                 # System configurations
└── var/log/             # Log files
```

### What Gets Persisted

By default, the following directories are persisted:
- `/home` - User home directories
- `/etc` - System configurations
- `/var/log` - Log files
- `/root` - Root user home
- `/usr/local` - Local installations

## Usage

### Flashing with Persistence

#### Basic Persistence (Uses All Remaining Space)

```bash
sudo python3 -m usbfreedom.cli flash pentest.img /dev/sdX --persistence
```

#### Custom Persistence Size

```bash
# Flash with 4GB persistence partition
sudo python3 -m usbfreedom.cli flash pentest.img /dev/sdX --persistence --persistence-size 4096

# Flash with 8GB persistence partition
sudo python3 -m usbfreedom.cli flash pentest.img /dev/sdX --persistence --persistence-size 8192
```

### Listing Available Devices

```bash
python3 -m usbfreedom.cli list-devices
```

Output example:
```
Device          Size       Vendor          Model
----------------------------------------------------------------------
/dev/sdb           14.9GB SanDisk          Ultra
/dev/sdc           7.5GB  Kingston         DataTraveler

Found 2 device(s)
```

### Managing Persistence (On the Live System)

Once booted into the live system, use these commands:

#### Check Persistence Status

```bash
sudo persistence-status.sh
```

Output:
```
╔═══════════════════════════════════════════════════════════╗
║        USBFREEDOM Persistence Status                     ║
╚═══════════════════════════════════════════════════════════╝

✓ Persistence Partition: /dev/sdb2
✓ Status: ACTIVE (mounted at /persistence)

Disk Usage:
  Total: 7.5G
  Used: 2.1G (28%)
  Available: 5.4G

✓ Configuration: Found

Persisted Paths:
  • /home union
  • /var/log union
  • /etc union
  • /root union
  • /usr/local union
```

#### Enable Persistence Manually

```bash
sudo enable-persistence.sh
```

#### Disable Persistence

```bash
sudo disable-persistence.sh
```

#### Backup Persistence Data

```bash
# Backup to default location (/tmp/persistence-backup-TIMESTAMP)
sudo backup-persistence.sh

# Backup to custom location
sudo backup-persistence.sh /mnt/external/backup
```

## Boot Options

When the system boots, you'll see these menu options:

1. **USBFREEDOM with Persistence** - Normal boot with all changes saved
2. **USBFREEDOM (No Persistence)** - Boot without persistence (fresh state)
3. **USBFREEDOM (Failsafe)** - Persistence enabled with safe graphics mode

## Technical Details

### Overlayfs Implementation

Persistence uses Linux's overlayfs to layer changes on top of the read-only base system:

- **Lower layer**: Read-only squashfs from the base image
- **Upper layer**: `/persistence/upper` (read-write, stores changes)
- **Work directory**: `/persistence/work` (overlayfs metadata)
- **Merged**: The combined view presented to the system

### Boot Process

1. GRUB/Syslinux starts with kernel parameter `persistence persistence-label=persistence`
2. Initramfs detects the persistence partition by label
3. Persistence partition is mounted to `/persistence`
4. Overlayfs is configured for persisted paths
5. System continues boot with persistence active

### Filesystem Details

- **Boot partition**: FAT32 (compatible with UEFI)
- **Persistence partition**: ext4 (Linux native, supports permissions)
- **Partition table**: GPT (supports drives >2TB)

## Troubleshooting

### Persistence Not Working

1. Check if persistence partition exists:
   ```bash
   lsblk -f | grep persistence
   ```

2. Verify persistence.conf:
   ```bash
   sudo mount /dev/sdX2 /mnt
   cat /mnt/persistence.conf
   sudo umount /mnt
   ```

3. Check kernel boot parameters:
   ```bash
   cat /proc/cmdline | grep persistence
   ```

### Partition Not Found

If the system can't find the persistence partition:

1. Verify the label:
   ```bash
   sudo blkid | grep persistence
   ```

2. Re-label if needed:
   ```bash
   sudo e2label /dev/sdX2 persistence
   ```

### Space Issues

If persistence partition is full:

1. Check usage:
   ```bash
   df -h /persistence
   ```

2. Clean up:
   ```bash
   # Clear log files
   sudo journalctl --vacuum-size=100M

   # Remove old package caches
   sudo apt-get clean
   ```

3. Backup and recreate with larger partition:
   ```bash
   sudo backup-persistence.sh /external/backup
   # Re-flash with larger --persistence-size
   ```

## Best Practices

1. **Size Recommendations**:
   - Development work: 4-8GB
   - Security testing: 8-16GB
   - Data analysis: 16GB+

2. **Regular Backups**:
   - Schedule periodic backups of persistence data
   - Test restore procedures

3. **Monitoring**:
   - Check disk space regularly with `df -h /persistence`
   - Monitor for filesystem errors with `sudo fsck /dev/sdX2`

4. **Clean Installations**:
   - Use "No Persistence" boot option to test clean state
   - Reinstall packages instead of accumulating in persistence

## Limitations

- **Performance**: Writes to persistence are slower than RAM-based systems
- **Wear**: Frequent writes can wear out USB flash drives over time
- **Size**: Total persistence limited by USB drive capacity
- **Compatibility**: Requires live system with overlayfs support

## Advanced Configuration

### Custom Persistence Paths

Edit `/persistence/persistence.conf`:

```bash
# Add custom paths
/opt union
/var/cache bind

# Save and reboot
```

### Partition Encryption (Future Feature)

LUKS encryption for persistence partition is planned for a future release.

## Examples

### Development Workflow

```bash
# 1. Flash with 8GB persistence
sudo python3 -m usbfreedom.cli flash dev-kit.img /dev/sdb --persistence --persistence-size 8192

# 2. Boot and install tools
# (tools persist across reboots)

# 3. Backup before major changes
sudo backup-persistence.sh

# 4. Work with confidence
```

### Security Testing Workflow

```bash
# 1. Flash pentest kit with max persistence
sudo python3 -m usbfreedom.cli flash pentest.img /dev/sdb --persistence

# 2. Boot and configure tools

# 3. Save captured data to persistence

# 4. Reboot maintains all data and configs
```

## Contributing

To improve persistence features, see the development guide in the main README.
