import sys
print(f"Python version: {sys.version}")

try:
    import typing
    print(f"typing: {typing}")
    print(f"typing.List: {typing.List}")
except Exception as e:
    print(f"Error importing typing: {e}")

try:
    import yaml
    print(f"yaml: {yaml}")
except Exception as e:
    print(f"Error importing yaml: {e}")

try:
    from usbfreedom.core import Toolkit
    print("Successfully imported Toolkit")
except Exception as e:
    print(f"Error importing Toolkit: {e}")
    import traceback
    traceback.print_exc()
