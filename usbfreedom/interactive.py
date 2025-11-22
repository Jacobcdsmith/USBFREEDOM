"""Interactive menu system for module selection."""
import sys
from typing import List
from .core import Category, Module

def print_categories(categories: List[Category]) -> None:
    """Display available categories."""
    print("\n\033[1mSelect base category:\033[0m")
    for i, cat in enumerate(categories, 1):
        print(f"  {i}. {cat.name}")

def select_category(categories: List[Category]) -> Category:
    """Prompt user to select a category."""
    print_categories(categories)
    
    while True:
        try:
            choice = input("\n> ").strip()
            idx = int(choice) - 1
            if 0 <= idx < len(categories):
                return categories[idx]
            print(f"Please enter a number between 1 and {len(categories)}")
        except (ValueError, KeyError):
            print("Invalid input. Please enter a number.")
        except (EOFError, KeyboardInterrupt):
            print("\n\nAborted.")
            sys.exit(0)

def toggle_module(selected: List[str], module_id: str) -> None:
    """Toggle a module on/off in the selection."""
    if module_id in selected:
        selected.remove(module_id)
    else:
        selected.append(module_id)

def print_modules(category: Category, selected: List[str]) -> None:
    """Display modules with selection status."""
    print(f"\n\033[1mAvailable modules for {category.name}:\033[0m")
    for i, mod in enumerate(category.modules, 1):
        status = "\033[32m✓\033[0m" if mod.id in selected else " "
        packages_preview = ", ".join(mod.packages[:3])
        if len(mod.packages) > 3:
            packages_preview += f", +{len(mod.packages) - 3} more"
        print(f"  [{status}] {i}. {mod.name}")
        print(f"      {mod.description}")
        print(f"      \033[90m({packages_preview})\033[0m")

def select_modules(category: Category) -> List[str]:
    """Interactive module selection."""
    selected = []
    
    print(f"\n\033[1mYou selected: {category.name}\033[0m")
    print(f"Base ISO: {category.base_iso}\n")
    print("Toggle modules with numbers, 'a' for all, 'n' for none, 'd' when done")
    
    while True:
        print_modules(category, selected)
        try:
            choice = input("\n> ").strip().lower()
            
            if choice == 'd':
                if selected:
                    return selected
                print("Please select at least one module.")
                continue
            elif choice == 'a':
                selected = [mod.id for mod in category.modules]
                continue
            elif choice == 'n':
                selected = []
                continue
            
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(category.modules):
                    toggle_module(selected, category.modules[idx].id)
                else:
                    print(f"Please enter a number between 1 and {len(category.modules)}")
            except ValueError:
                print("Invalid input. Use numbers to toggle, 'a' for all, 'n' for none, 'd' when done")
                
        except (EOFError, KeyboardInterrupt):
            print("\n\nAborted.")
            sys.exit(0)
