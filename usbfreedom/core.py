import os
import subprocess
import shutil
import tempfile
import logging
import yaml
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional
from .utils import run_command, ensure_dir, get_project_root
from .partition import PartitionManager, PartitionScheme
from .persistence import PersistenceBuilder, PersistenceConfig

logger = logging.getLogger(__name__)

@dataclass
class Toolkit:
    name: str
    id: str
    base_iso: str
    description: str
    install_script: str

    @classmethod
    def load_from_yaml(cls, path: Path) -> List['Toolkit']:
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        return [cls(**item) for item in data.get('toolkits', [])]

@dataclass
class Module:
    id: str
    name: str
    description: str
    packages: List[str]

@dataclass
class Category:
    name: str
    id: str
    base_iso: str
    modules: List[Module]
    
    @classmethod
    def load_from_yaml(cls, path: Path) -> List['Category']:
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        categories = []
        for cat_data in data.get('categories', []):
            modules = [Module(**mod) for mod in cat_data.get('modules', [])]
            categories.append(cls(
                name=cat_data['name'],
                id=cat_data['id'],
                base_iso=cat_data['base_iso'],
                modules=modules
            ))
        return categories


class Builder:
    def __init__(self, toolkit: Toolkit, output_path: Path):
        self.toolkit = toolkit
        self.output_path = output_path
        self.project_root = get_project_root()

    def build(self):
        """Build the toolkit image."""
        logger.info(f"Building toolkit: {self.toolkit.name}")
        
        iso_path = self.project_root / 'base_iso' / self.toolkit.base_iso
        if not iso_path.exists():
            raise FileNotFoundError(f"Base ISO not found: {iso_path}")

        with tempfile.TemporaryDirectory() as work_dir:
            work_path = Path(work_dir)
            extract_path = work_path / 'extract'
            ensure_dir(extract_path)

            # Extract ISO
            logger.info("Extracting ISO...")
            # Using 7z as in the original script
            run_command(['7z', 'x', str(iso_path), f'-o{extract_path}'])

            # Apply overlay
            logger.info("Applying overlay...")
            overlay_path = self.project_root / 'core' / 'overlay'
            if overlay_path.exists():
                shutil.copytree(overlay_path, extract_path, dirs_exist_ok=True)
            
            # Run install script if needed (conceptually, though original just copied overlay)
            # The original build.sh just copied overlay. The install scripts seem to be for post-boot or inside the image?
            # For now, we replicate build.sh behavior: extract ISO + copy overlay -> repack
            
            # Create bootable image
            logger.info("Creating bootable image...")
            # mkisofs arguments from build.sh
            cmd = [
                'mkisofs', '-o', str(self.output_path),
                '-b', 'isolinux/isolinux.bin',
                '-c', 'isolinux/boot.cat',
                '-no-emul-boot',
                '-boot-load-size', '4',
                '-boot-info-table',
                '-R', '-J', '-v', '-T',
                str(extract_path)
            ]
            run_command(cmd)
            
        logger.info(f"Image created successfully: {self.output_path}")

class CustomKitBuilder:
    """Builder for custom kits with selected modules."""
    
    def __init__(self, category: Category, selected_modules: List[str], output_path: Path):
        self.category = category
        self.selected_modules = selected_modules
        self.output_path = output_path
        self.project_root = get_project_root()
    
    def build(self):
        """Build a custom kit with selected modules."""
        logger.info(f"Building custom kit: {self.category.name}")
        logger.info(f"Selected modules: {', '.join(self.selected_modules)}")
        
        iso_path = self.project_root / 'base_iso' / self.category.base_iso
        if not iso_path.exists():
            raise FileNotFoundError(f"Base ISO not found: {iso_path}")
        
        # Get selected module objects
        modules = [m for m in self.category.modules if m.id in self.selected_modules]
        
        with tempfile.TemporaryDirectory() as work_dir:
            work_path = Path(work_dir)
            extract_path = work_path / 'extract'
            ensure_dir(extract_path)
            
            # Extract ISO
            logger.info("Extracting ISO...")
            run_command(['7z', 'x', str(iso_path), f'-o{extract_path}'])
            
            # Apply base overlay if it exists
            logger.info("Applying base overlay...")
            overlay_path = self.project_root / 'core' / 'overlay'
            if overlay_path.exists():
                shutil.copytree(overlay_path, extract_path, dirs_exist_ok=True)
            
            # Create installation script for selected modules
            logger.info("Creating module installation script...")
            install_script_path = extract_path / 'install_modules.sh'
            with open(install_script_path, 'w') as f:
                f.write("#!/bin/bash\n")
                f.write("set -e\n\n")
                f.write("echo 'Installing selected modules...'\n\n")
                
                for module in modules:
                    f.write(f"\n# Installing {module.name}\n")
                    f.write(f"echo 'Installing {module.name}...'\n")
                    packages = ' '.join(module.packages)
                    f.write(f"apt-get update && apt-get install -y {packages}\n")
            
            # Make script executable
            os.chmod(install_script_path, 0o755)
            
            # Create bootable image
            logger.info("Creating bootable image...")
            cmd = [
                'mkisofs', '-o', str(self.output_path),
                '-b', 'isolinux/isolinux.bin',
                '-c', 'isolinux/boot.cat',
                '-no-emul-boot',
                '-boot-load-size', '4',
                '-boot-info-table',
                '-R', '-J', '-v', '-T',
                str(extract_path)
            ]
            run_command(cmd)
        
        logger.info(f"Custom kit created successfully: {self.output_path}")

class Flasher:
    def __init__(self, image_path: Path, device_path: str, persistence_enabled: bool = False,
                 persistence_size_mb: int = -1):
        self.image_path = image_path
        self.device_path = device_path
        self.persistence_enabled = persistence_enabled
        self.persistence_size_mb = persistence_size_mb

    def flash(self):
        """Flash the image to the device."""
        if not self.image_path.exists():
            raise FileNotFoundError(f"Image file not found: {self.image_path}")

        # Basic safety check for device path (very minimal)
        if not os.path.exists(self.device_path):
             raise FileNotFoundError(f"Target device not found: {self.device_path}")

        logger.warning(f"All data on {self.device_path} will be overwritten.")
        # In a real CLI we'd ask for confirmation here, but the class just does the work.
        # The CLI layer should handle the prompt.

        if self.persistence_enabled:
            logger.info("Flashing with persistence support enabled")
            self._flash_with_persistence()
        else:
            logger.info("Flashing without persistence (standard mode)")
            self._flash_simple()

    def _flash_simple(self):
        """Simple flash without persistence (original behavior)."""
        logger.info(f"Flashing {self.image_path} to {self.device_path}...")

        # Unmount logic (Linux/macOS specific, simplified)
        import platform
        system = platform.system()

        if system == 'Linux':
             # Try to unmount
             run_command(['umount', f'{self.device_path}*'], check=False)
             dd_bs = '4M'
             conv = 'fsync'
        elif system == 'Darwin': # macOS
             # Try to unmount
             run_command(['diskutil', 'unmountDisk', self.device_path], check=False)
             dd_bs = '1m'
             conv = 'sync'
        else:
            dd_bs = '4M'
            conv = 'fsync'

        cmd = [
            'dd',
            f'if={self.image_path}',
            f'of={self.device_path}',
            f'bs={dd_bs}',
            'status=progress',
            f'conv={conv}'
        ]

        subprocess.run(cmd, check=True)

        if system == 'Linux':
            run_command(['sync'])

        logger.info("Flash completed successfully")

    def _flash_with_persistence(self):
        """Flash image and create persistence partition."""
        logger.info("Starting flash with persistence...")

        # Step 1: Get image size
        image_size = os.path.getsize(self.image_path)
        logger.info(f"Image size: {image_size / (1024**2):.1f} MB")

        # Step 2: Setup partition manager
        pm = PartitionManager(self.device_path)

        # Step 3: Unmount all partitions
        logger.info("Unmounting existing partitions...")
        pm.unmount_all()

        # Step 4: Wipe device
        logger.info("Wiping device (this may take a moment)...")
        pm.wipe_device()

        # Step 5: Get device info
        dev_info = pm.get_device_info()
        if dev_info:
            logger.info(f"Device: {dev_info}")

        # Step 6: Calculate partition sizes
        # Boot partition needs to fit the image plus some headroom
        boot_size_mb = int((image_size / (1024**2)) * 1.2) + 100  # 20% headroom + 100MB

        scheme = PartitionScheme(
            boot_size_mb=boot_size_mb,
            persistence_size_mb=self.persistence_size_mb
        )

        # Step 7: Create partition table
        logger.info("Creating partition table...")
        pm.create_partition_table(scheme)

        # Step 8: Format partitions
        logger.info("Formatting partitions...")
        pm.format_partitions()

        # Step 9: Flash image to first partition
        logger.info("Flashing image to boot partition...")
        boot_partition = pm._get_partition_path(1)

        cmd = [
            'dd',
            f'if={self.image_path}',
            f'of={boot_partition}',
            'bs=4M',
            'status=progress',
            'conv=fsync'
        ]
        subprocess.run(cmd, check=True)
        run_command(['sync'])

        # Step 10: Setup persistence on second partition
        logger.info("Setting up persistence structure...")
        persist_partition = pm._get_partition_path(2)
        pb = PersistenceBuilder(persist_partition)

        if pb.setup_persistence_structure():
            logger.info("Persistence structure created successfully")
        else:
            logger.error("Failed to create persistence structure")
            raise RuntimeError("Persistence setup failed")

        # Step 11: Verify persistence
        logger.info("Verifying persistence...")
        if pb.verify_persistence():
            logger.info("Persistence verification passed")
        else:
            logger.warning("Persistence verification failed")

        # Step 12: Final sync
        run_command(['sync'])

        logger.info("="*60)
        logger.info("Flash with persistence completed successfully!")
        logger.info("="*60)
        logger.info(f"Device: {self.device_path}")
        logger.info(f"Boot partition: {boot_partition}")
        logger.info(f"Persistence partition: {persist_partition}")

        # Show partition info
        boot_info = pm.get_partition_info(1)
        persist_info = pm.get_partition_info(2)
        logger.info(f"Boot size: {boot_info.get('size', 'Unknown')}")
        logger.info(f"Persistence size: {persist_info.get('size', 'Unknown')}")
        logger.info("="*60)
