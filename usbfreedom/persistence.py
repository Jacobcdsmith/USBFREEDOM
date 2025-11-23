"""Persistence configuration and setup for live USB systems."""
import logging
import tempfile
from pathlib import Path
from typing import Optional
from .utils import run_command

logger = logging.getLogger(__name__)


class PersistenceConfig:
    """Configuration for persistence setup."""

    def __init__(self, partition_label: str = "persistence"):
        self.partition_label = partition_label
        self.mount_point = Path("/persistence")
        self.upper_dir = Path("/persistence/upper")
        self.work_dir = Path("/persistence/work")
        self.home_dir = Path("/persistence/home")

    def get_persistence_paths(self) -> list:
        """Get list of directories that should be persisted."""
        return [
            "/home",
            "/var/log",
            "/etc",
            "/root",
            "/usr/local",
            "/opt"
        ]


class PersistenceBuilder:
    """Builds persistence structure on a partition."""

    def __init__(self, partition_device: str):
        self.partition_device = partition_device

    def setup_persistence_structure(self) -> bool:
        """Create persistence directory structure on the partition."""
        logger.info("Setting up persistence structure")

        # Create temporary mount point
        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir)

            try:
                # Mount the persistence partition
                logger.info(f"Mounting {self.partition_device} to {mount_point}")
                run_command(['mount', self.partition_device, str(mount_point)])

                # Create directory structure
                directories = [
                    'upper',      # Overlayfs upper directory
                    'work',       # Overlayfs work directory
                    'home',       # User home directories
                    'root',       # Root home
                    'etc',        # Configuration files
                    'var/log',    # Log files
                ]

                for dir_path in directories:
                    full_path = mount_point / dir_path
                    logger.info(f"Creating directory: {full_path}")
                    full_path.mkdir(parents=True, exist_ok=True)

                # Create persistence.conf file
                # This file tells the live system what to persist
                conf_path = mount_point / 'persistence.conf'
                logger.info(f"Creating {conf_path}")

                with open(conf_path, 'w') as f:
                    f.write("# Persistence configuration for USBFREEDOM\n")
                    f.write("# Each line specifies a directory to persist\n\n")
                    f.write("/home union\n")
                    f.write("/var/log union\n")
                    f.write("/etc union\n")
                    f.write("/root union\n")
                    f.write("/usr/local union\n")

                # Sync to ensure everything is written
                run_command(['sync'])

                logger.info("Persistence structure created successfully")
                return True

            except Exception as e:
                logger.error(f"Failed to create persistence structure: {e}")
                return False

            finally:
                # Unmount
                try:
                    run_command(['umount', str(mount_point)], check=False)
                except Exception:
                    pass

    def verify_persistence(self) -> bool:
        """Verify that persistence structure exists and is valid."""
        logger.info("Verifying persistence structure")

        with tempfile.TemporaryDirectory() as tmpdir:
            mount_point = Path(tmpdir)

            try:
                # Mount the partition
                run_command(['mount', self.partition_device, str(mount_point)])

                # Check for required directories
                required = ['upper', 'work', 'persistence.conf']
                for item in required:
                    if not (mount_point / item).exists():
                        logger.error(f"Missing required item: {item}")
                        return False

                logger.info("Persistence verification passed")
                return True

            except Exception as e:
                logger.error(f"Verification failed: {e}")
                return False

            finally:
                try:
                    run_command(['umount', str(mount_point)], check=False)
                except Exception:
                    pass


class GrubConfigurator:
    """Configures GRUB bootloader for persistence support."""

    @staticmethod
    def generate_grub_entry(persistence_enabled: bool = True) -> str:
        """Generate GRUB menu entry with persistence support."""
        if persistence_enabled:
            return """
menuentry "USBFREEDOM with Persistence" {
    set gfxpayload=keep
    linux /live/vmlinuz boot=live persistence persistence-label=persistence quiet splash
    initrd /live/initrd.img
}

menuentry "USBFREEDOM (No Persistence)" {
    set gfxpayload=keep
    linux /live/vmlinuz boot=live nopersistence quiet splash
    initrd /live/initrd.img
}

menuentry "USBFREEDOM (Failsafe)" {
    set gfxpayload=keep
    linux /live/vmlinuz boot=live persistence persistence-label=persistence nomodeset
    initrd /live/initrd.img
}
"""
        else:
            return """
menuentry "USBFREEDOM" {
    set gfxpayload=keep
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}

menuentry "USBFREEDOM (Failsafe)" {
    set gfxpayload=keep
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd.img
}
"""

    @staticmethod
    def inject_grub_config(boot_partition_mount: Path, persistence_enabled: bool = True):
        """Inject GRUB configuration into boot partition."""
        grub_cfg_path = boot_partition_mount / 'boot' / 'grub' / 'grub.cfg'

        # Check if path exists, create if needed
        grub_cfg_path.parent.mkdir(parents=True, exist_ok=True)

        # Read existing config if it exists
        existing_config = ""
        if grub_cfg_path.exists():
            with open(grub_cfg_path, 'r') as f:
                existing_config = f.read()

        # Generate new entry
        new_entry = GrubConfigurator.generate_grub_entry(persistence_enabled)

        # If config exists and doesn't have persistence entry, append
        if existing_config and 'persistence' not in existing_config.lower():
            with open(grub_cfg_path, 'a') as f:
                f.write('\n\n# USBFREEDOM Persistence Configuration\n')
                f.write(new_entry)
        elif not existing_config:
            # Create new config
            with open(grub_cfg_path, 'w') as f:
                f.write('# GRUB Configuration for USBFREEDOM\n')
                f.write('set timeout=10\n')
                f.write('set default=0\n\n')
                f.write(new_entry)

        logger.info(f"GRUB configuration written to {grub_cfg_path}")


class SyslinuxConfigurator:
    """Configures Syslinux/Isolinux bootloader for persistence support."""

    @staticmethod
    def generate_syslinux_config(persistence_enabled: bool = True) -> str:
        """Generate Syslinux configuration with persistence support."""
        if persistence_enabled:
            return """DEFAULT live-persistence
TIMEOUT 100
PROMPT 1

LABEL live-persistence
    MENU LABEL USBFREEDOM with Persistence
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live persistence persistence-label=persistence quiet splash

LABEL live-no-persist
    MENU LABEL USBFREEDOM (No Persistence)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live nopersistence quiet splash

LABEL live-failsafe
    MENU LABEL USBFREEDOM (Failsafe)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live persistence nomodeset
"""
        else:
            return """DEFAULT live
TIMEOUT 100
PROMPT 1

LABEL live
    MENU LABEL USBFREEDOM
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live quiet splash

LABEL live-failsafe
    MENU LABEL USBFREEDOM (Failsafe)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live nomodeset
"""

    @staticmethod
    def inject_syslinux_config(boot_partition_mount: Path, persistence_enabled: bool = True):
        """Inject Syslinux configuration into boot partition."""
        # Try multiple possible locations
        possible_paths = [
            boot_partition_mount / 'isolinux' / 'isolinux.cfg',
            boot_partition_mount / 'syslinux' / 'syslinux.cfg',
            boot_partition_mount / 'boot' / 'syslinux' / 'syslinux.cfg',
        ]

        config_content = SyslinuxConfigurator.generate_syslinux_config(persistence_enabled)

        for cfg_path in possible_paths:
            if cfg_path.parent.exists():
                logger.info(f"Writing Syslinux config to {cfg_path}")
                with open(cfg_path, 'w') as f:
                    f.write(config_content)
                return True

        logger.warning("No Syslinux configuration location found")
        return False
