import argparse
import logging
import sys
from pathlib import Path
from .core import Toolkit, Builder, Flasher, Category, CustomKitBuilder
from .utils import get_project_root
from .interactive import select_category, select_modules
from .partition import list_usb_devices

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def list_toolkits(toolkits):
    print(f"{'ID':<15} {'Name':<30} {'Description'}")
    print("-" * 80)
    for tk in toolkits:
        print(f"{tk.id:<15} {tk.name:<30} {tk.description}")

def main():
    parser = argparse.ArgumentParser(description="USBFREEDOM - USB Toolkit Builder")
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # List command
    subparsers.add_parser('list-toolkits', help='List available toolkits')

    # Build command
    build_parser = subparsers.add_parser('build', help='Build a toolkit image')
    build_parser.add_argument('toolkit_id', help='ID of the toolkit to build')
    build_parser.add_argument('output', help='Output image path')

    # Flash command
    flash_parser = subparsers.add_parser('flash', help='Flash an image to a USB drive')
    flash_parser.add_argument('image', help='Path to the image file')
    flash_parser.add_argument('device', help='Target device path (e.g., /dev/sdX)')
    flash_parser.add_argument('--persistence', action='store_true',
                             help='Enable persistence (creates separate partition for data)')
    flash_parser.add_argument('--persistence-size', type=int, metavar='MB',
                             help='Size of persistence partition in MB (-1 for all remaining space)')

    # List devices command
    subparsers.add_parser('list-devices', help='List available USB storage devices')
    
    # List categories command
    subparsers.add_parser('list-categories', help='List available module categories')
    
    # Build custom command
    build_custom_parser = subparsers.add_parser('build-custom', help='Build a custom kit with interactive module selection')
    build_custom_parser.add_argument('output', help='Output image path')

    args = parser.parse_args()

    # Load toolkits
    project_root = get_project_root()
    config_path = project_root / 'toolkits.yaml'
    
    try:
        toolkits = Toolkit.load_from_yaml(config_path)
    except FileNotFoundError:
        logger.error(f"Configuration file not found at {config_path}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error loading configuration: {e}")
        sys.exit(1)

    if args.command == 'list-toolkits':
        list_toolkits(toolkits)

    elif args.command == 'build':
        toolkit = next((t for t in toolkits if t.id == args.toolkit_id), None)
        if not toolkit:
            logger.error(f"Toolkit with ID '{args.toolkit_id}' not found.")
            sys.exit(1)
        
        builder = Builder(toolkit, Path(args.output))
        try:
            builder.build()
        except Exception as e:
            logger.error(f"Build failed: {e}")
            sys.exit(1)

    elif args.command == 'flash':
        # Confirm before flashing
        print(f"WARNING: All data on {args.device} will be overwritten!")

        if args.persistence:
            print(f"Persistence will be ENABLED")
            if args.persistence_size:
                print(f"Persistence size: {args.persistence_size} MB")
            else:
                print(f"Persistence size: All remaining space")

        confirm = input("Are you sure you want to continue? [y/N]: ")
        if confirm.lower() != 'y':
            print("Aborted.")
            sys.exit(0)

        # Create flasher with persistence options
        persistence_enabled = args.persistence
        persistence_size = args.persistence_size if args.persistence_size else -1

        flasher = Flasher(
            Path(args.image),
            args.device,
            persistence_enabled=persistence_enabled,
            persistence_size_mb=persistence_size
        )

        try:
            flasher.flash()
        except Exception as e:
            logger.error(f"Flash failed: {e}")
            sys.exit(1)

    elif args.command == 'list-devices':
        print("Scanning for USB storage devices...")
        devices = list_usb_devices()

        if not devices:
            print("No removable USB storage devices found.")
            sys.exit(0)

        print(f"\n{'Device':<15} {'Size':<10} {'Vendor':<15} {'Model'}")
        print("-" * 70)
        for dev in devices:
            print(f"{dev.path:<15} {dev.size_gb:>8.1f}GB {dev.vendor:<15} {dev.model}")

        print(f"\nFound {len(devices)} device(s)")
        print("\nTo flash with persistence:")
        print(f"  usbfreedom flash <image> <device> --persistence --persistence-size <MB>")

    elif args.command == 'list-categories':
        # Load categories from modules.yaml
        modules_path = project_root / 'modules.yaml'
        try:
            categories = Category.load_from_yaml(modules_path)
        except FileNotFoundError:
            logger.error(f"Modules configuration not found at {modules_path}")
            sys.exit(1)
        
        print(f"{'ID':<15} {'Name':<40} {'Modules'}")
        print("-" * 80)
        for cat in categories:
            print(f"{cat.id:<15} {cat.name:<40} {len(cat.modules)} modules")
    
    elif args.command == 'build-custom':
        # Load categories from modules.yaml
        modules_path = project_root / 'modules.yaml'
        try:
            categories = Category.load_from_yaml(modules_path)
        except FileNotFoundError:
            logger.error(f"Modules configuration not found at {modules_path}")
            sys.exit(1)
        
        # Interactive selection
        category = select_category(categories)
        selected_modules = select_modules(category)
        
        # Build custom kit
        builder = CustomKitBuilder(category, selected_modules, Path(args.output))
        try:
            builder.build()
        except Exception as e:
            logger.error(f"Build failed: {e}")
            sys.exit(1)

    else:
        parser.print_help()

if __name__ == '__main__':
    main()
