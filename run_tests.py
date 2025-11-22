import unittest
import sys
import traceback
from tests.test_build_script import TestUSBFreedom

def run_manual():
    test = TestUSBFreedom()
    methods = [m for m in dir(test) if m.startswith('test_')]
    
    failed = False
    with open('test_failure.log', 'w') as f:
        for method_name in methods:
            print(f"Running {method_name}...")
            try:
                # Set up
                test.setUp()
                # Run test
                getattr(test, method_name)()
                # Tear down
                test.tearDown()
                print("PASS")
            except Exception:
                print(f"FAIL: {method_name}")
                f.write(f"FAIL: {method_name}\n")
                traceback.print_exc(file=f)
                failed = True
            
    if failed:
        sys.exit(1)

if __name__ == '__main__':
    run_manual()
