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
    def __init__(self, image_path: Path, device_path: str):
        self.image_path = image_path
        self.device_path = device_path

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

        logger.info(f"Flashing {self.image_path} to {self.device_path}...")
        
        # Unmount logic (Linux/macOS specific, simplified)
        # In a cross-platform python script, we might want to use a library or platform checks
        # For now, keeping it close to the bash script but wrapping in python
        
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
            # Windows? dd might not exist. 
            # The original script was bash, implying Linux/macOS/WSL.
            # We will assume dd is available or this is running in a compatible env.
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
        
        # dd writes to stderr for progress, so we might want to let it stream to user
        # run_command captures output. For flashing, we might want to use subprocess.run directly without capture
        # to show progress bar.
        subprocess.run(cmd, check=True)
        
        if system == 'Linux':
            run_command(['sync'])
            
        logger.info("Done.")
