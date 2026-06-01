"""Partition management for USB devices with persistence support."""
import subprocess
import logging
import json
from dataclasses import dataclass
from typing import List, Optional, Tuple
from .utils import run_command

logger = logging.getLogger(__name__)

# Partition and filesystem type identifiers
PARTITION_TABLE_TYPE = 'gpt'
BOOT_FILESYSTEM = 'fat32'
PERSIST_FILESYSTEM = 'ext4'
PARTITION_START_MIB = 1  # 1MiB alignment offset for the first partition
LSBLK_DISK_TYPE = 'disk'
UNKNOWN_DEVICE_FIELD = 'Unknown'


@dataclass
class DeviceInfo:
    """Information about a USB device."""
    path: str
    size_bytes: int
    vendor: str
    model: str
    removable: bool

    @property
    def size_gb(self) -> float:
        """Size in gigabytes."""
        return self.size_bytes / (1024**3)

    def __str__(self):
        return f"{self.path} ({self.size_gb:.1f}GB) - {self.vendor} {self.model}"


@dataclass
class PartitionScheme:
    """Defines partition layout for persistence."""
    boot_size_mb: int  # Size of bootable partition
    persistence_size_mb: int  # Size of persistence partition (-1 for remaining)

    BUFFER_SIZE_MB: int = 100  # Buffer space to leave at end of device

    def calculate_sizes(self, total_size_bytes: int) -> Tuple[int, int]:
        """Calculate actual partition sizes in bytes."""
        boot_bytes = self.boot_size_mb * 1024 * 1024

        if self.persistence_size_mb == -1:
            # Use remaining space
            persistence_bytes = total_size_bytes - boot_bytes - (self.BUFFER_SIZE_MB * 1024 * 1024)
        else:
            persistence_bytes = self.persistence_size_mb * 1024 * 1024

        return boot_bytes, persistence_bytes


class PartitionManager:
    """Manages partition operations on USB devices."""

    def __init__(self, device_path: str):
        self.device_path = device_path
        if not self._is_block_device():
            raise ValueError(f"Not a block device: {device_path}")

    def _is_block_device(self) -> bool:
        """Check if path is a block device."""
        try:
            result = subprocess.run(
                ['test', '-b', self.device_path],
                check=False
            )
            return result.returncode == 0
        except Exception:
            return False

    def get_device_info(self) -> Optional[DeviceInfo]:
        """Get information about the device."""
        try:
            # Use lsblk to get device info
            result = run_command([
                'lsblk', '-n', '-b', '-o', 'SIZE,VENDOR,MODEL,RM',
                self.device_path
            ], check=False)

            if result.returncode != 0:
                return None

            parts = result.stdout.strip().split()
            if len(parts) >= 4:
                size_bytes = int(parts[0])
                vendor = parts[1] if len(parts) > 1 else UNKNOWN_DEVICE_FIELD
                model = parts[2] if len(parts) > 2 else UNKNOWN_DEVICE_FIELD
                removable = parts[3] == '1' if len(parts) > 3 else False

                return DeviceInfo(
                    path=self.device_path,
                    size_bytes=size_bytes,
                    vendor=vendor,
                    model=model,
                    removable=removable
                )
        except Exception as e:
            logger.error(f"Failed to get device info: {type(e).__name__}: {e}")

        return None

    def unmount_all(self):
        """Unmount all partitions on the device."""
        logger.info(f"Unmounting all partitions on {self.device_path}")

        # Find all mounted partitions
        try:
            result = run_command(['mount'], check=False)
            mounted = [line for line in result.stdout.split('\n')
                      if self.device_path in line]

            for mount_line in mounted:
                parts = mount_line.split()
                if parts:
                    partition = parts[0]
                    logger.info(f"Unmounting {partition}")
                    run_command(['umount', partition], check=False)
        except Exception as e:
            logger.warning(f"Error during unmount: {e}")

    def wipe_device(self):
        """Wipe partition table and filesystem signatures."""
        logger.info(f"Wiping {self.device_path}")

        # Use wipefs to remove filesystem signatures
        try:
            run_command(['wipefs', '-a', self.device_path], check=False)
        except Exception as e:
            logger.warning(f"wipefs failed: {e}")

        # Zero out first and last MB for good measure
        try:
            # First MB
            run_command([
                'dd', 'if=/dev/zero', f'of={self.device_path}',
                'bs=1M', 'count=1', 'conv=fsync'
            ], check=False)

            # Get device size
            result = run_command(['blockdev', '--getsize64', self.device_path])
            size = int(result.stdout.strip())

            # Last MB
            run_command([
                'dd', 'if=/dev/zero', f'of={self.device_path}',
                f'bs=1M', f'seek={size // (1024*1024) - 1}', 'count=1', 'conv=fsync'
            ], check=False)
        except Exception as e:
            logger.warning(f"dd wipe failed: {e}")

    def create_partition_table(self, scheme: PartitionScheme):
        """Create GPT partition table with boot and persistence partitions."""
        logger.info("Creating partition table")

        # Get device size
        result = run_command(['blockdev', '--getsize64', self.device_path])
        total_size = int(result.stdout.strip())

        boot_size, persist_size = scheme.calculate_sizes(total_size)

        logger.info(f"Boot partition: {boot_size // (1024*1024)}MB")
        logger.info(f"Persistence partition: {persist_size // (1024*1024)}MB")

        # Create partition table using parted
        # First, create GPT label
        run_command(['parted', '-s', self.device_path, 'mklabel', PARTITION_TABLE_TYPE])

        # Create boot partition (FAT32, bootable)
        # Start at PARTITION_START_MIB for alignment
        boot_end_mb = PARTITION_START_MIB + (boot_size // (1024 * 1024))
        run_command([
            'parted', '-s', self.device_path,
            'mkpart', 'primary', BOOT_FILESYSTEM, f'{PARTITION_START_MIB}MiB', f'{boot_end_mb}MiB'
        ])

        # Set boot flag
        run_command(['parted', '-s', self.device_path, 'set', '1', 'boot', 'on'])

        # Create persistence partition (ext4)
        run_command([
            'parted', '-s', self.device_path,
            'mkpart', 'primary', PERSIST_FILESYSTEM, f'{boot_end_mb}MiB', '100%'
        ])

        # Sync to ensure partition table is written
        run_command(['sync'])

        # Re-read partition table and wait for kernel to recognize new partitions
        run_command(['partprobe', self.device_path], check=False)
        run_command(['udevadm', 'settle'], check=False)

        logger.info("Partition table created successfully")

    def format_partitions(self, boot_label: str = "USBBOOT", persist_label: str = "persistence"):
        """Format partitions with appropriate filesystems."""
        # Determine partition device names
        boot_part = self.get_partition_path(1)
        persist_part = self.get_partition_path(2)

        logger.info(f"Formatting boot partition: {boot_part}")
        # Format boot partition as FAT32
        run_command(['mkfs.vfat', '-F', '32', '-n', boot_label, boot_part])

        logger.info(f"Formatting persistence partition: {persist_part}")
        # Format persistence partition as ext4
        run_command(['mkfs.ext4', '-F', '-L', persist_label, persist_part])

        run_command(['sync'])
        logger.info("Partitions formatted successfully")

    def get_partition_path(self, partition_num: int) -> str:
        """Get the device path for a partition number."""
        # Handle both /dev/sdX and /dev/nvmeXnY naming
        if 'nvme' in self.device_path or 'mmcblk' in self.device_path:
            return f"{self.device_path}p{partition_num}"
        else:
            return f"{self.device_path}{partition_num}"

    def get_partition_info(self, partition_num: int) -> dict:
        """Get information about a specific partition."""
        part_path = self.get_partition_path(partition_num)

        try:
            result = run_command([
                'lsblk', '-n', '-o', 'SIZE,FSTYPE,LABEL', part_path
            ], check=False)

            if result.returncode == 0:
                parts = result.stdout.strip().split()
                return {
                    'path': part_path,
                    'size': parts[0] if len(parts) > 0 else 'Unknown',
                    'fstype': parts[1] if len(parts) > 1 else 'Unknown',
                    'label': parts[2] if len(parts) > 2 else ''
                }
        except Exception as e:
            logger.error(f"Failed to get partition info: {type(e).__name__}: {e}")

        return {'path': part_path}


def list_usb_devices() -> List[DeviceInfo]:
    """List all removable USB storage devices."""
    devices = []

    try:
        # Use JSON output to avoid whitespace parsing issues in vendor/model fields.
        result = run_command([
            'lsblk', '-J', '-d', '-o', 'NAME,SIZE,VENDOR,MODEL,RM,TYPE', '-b'
        ], check=False)

        if result.returncode != 0:
            return devices

        payload = json.loads(result.stdout or "{}")
        for dev in payload.get('blockdevices', []):
            removable = str(dev.get('rm', '0')) == '1'
            dev_type = dev.get('type', '')
            if not (removable and dev_type == LSBLK_DISK_TYPE):
                continue

            name = dev.get('name', '')
            if not name:
                continue
            size_raw = dev.get('size', 0)
            try:
                size_bytes = int(size_raw)
            except (TypeError, ValueError):
                continue

            vendor = (dev.get('vendor') or '').strip() or UNKNOWN_DEVICE_FIELD
            model = (dev.get('model') or '').strip() or UNKNOWN_DEVICE_FIELD

            devices.append(DeviceInfo(
                path=f'/dev/{name}',
                size_bytes=size_bytes,
                vendor=vendor,
                model=model,
                removable=removable
            ))
    except Exception as e:
        logger.error(f"Failed to list USB devices: {type(e).__name__}: {e}")

    return devices
