import unittest
import shutil
import tempfile
import os
from pathlib import Path
from unittest.mock import MagicMock, patch
from usbfreedom.core import Toolkit, Builder, Flasher

class TestUSBFreedom(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self.tmp_dir.name)
        
        self.mock_toolkit = Toolkit(
            name="Test Kit",
            id="test",
            base_iso="test.iso",
            description="Test Description",
            install_script="install.sh"
        )

    def tearDown(self):
        self.tmp_dir.cleanup()

    @patch('usbfreedom.core.shutil.copytree')
    @patch('usbfreedom.core.run_command')
    def test_builder(self, mock_copytree, mock_run_command):
        # Top patch: copytree -> passed first
        # Bottom patch: run_command -> passed second
        
        # Setup
        output_path = self.tmp_path / "output.img"
        builder = Builder(self.mock_toolkit, output_path)
        
        # Mock project root to point to tmp_path
        with patch('usbfreedom.core.get_project_root', return_value=self.tmp_path):
            # Create dummy ISO and overlay
            (self.tmp_path / 'base_iso').mkdir()
            (self.tmp_path / 'base_iso' / 'test.iso').touch()
            (self.tmp_path / 'core' / 'overlay').mkdir(parents=True)

            # Run build
            builder.build()

        # Verify
        # run_command called twice (7z, mkisofs)
        self.assertEqual(mock_run_command.call_count, 2) 
        # copytree called once
        self.assertTrue(mock_copytree.called)

    @patch('usbfreedom.core.run_command')
    @patch('usbfreedom.core.subprocess.run')
    def test_flasher(self, mock_run_command, mock_subprocess_run):
        # Top patch: run_command -> passed first
        # Bottom patch: subprocess.run -> passed second
        
        # Setup
        image_path = self.tmp_path / "test.img"
        image_path.touch()
        device_path = self.tmp_path / "dev" / "sdb" # Fake device path
        (self.tmp_path / "dev").mkdir(parents=True, exist_ok=True)
        
        # Mock os.path.exists for device check
        with patch('os.path.exists', return_value=True):
            flasher = Flasher(image_path, str(device_path))
            flasher.flash()

        # Verify
        self.assertTrue(mock_subprocess_run.called) # dd
        
    def test_toolkit_load(self):
        config_file = self.tmp_path / "toolkits.yaml"
        with open(config_file, 'w') as f:
            f.write("""
toolkits:
  - name: "Test Kit"
    id: "test"
    base_iso: "test.iso"
    description: "Test Description"
    install_script: "install.sh"
""")
        
        toolkits = Toolkit.load_from_yaml(config_file)
        self.assertEqual(len(toolkits), 1)
        self.assertEqual(toolkits[0].id, "test")

if __name__ == '__main__':
    unittest.main()
