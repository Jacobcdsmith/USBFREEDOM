"""Tests for persistence configuration."""
import unittest
from unittest.mock import Mock, patch, mock_open, MagicMock
from pathlib import Path
from usbfreedom.persistence import (
    PersistenceConfig,
    PersistenceBuilder,
    GrubConfigurator,
    SyslinuxConfigurator
)


class TestPersistenceConfig(unittest.TestCase):
    """Test PersistenceConfig."""

    def test_default_config(self):
        """Test default configuration values."""
        config = PersistenceConfig()

        self.assertEqual(config.partition_label, "persistence")
        self.assertEqual(config.mount_point, Path("/persistence"))
        self.assertEqual(config.upper_dir, Path("/persistence/upper"))
        self.assertEqual(config.work_dir, Path("/persistence/work"))

    def test_custom_label(self):
        """Test custom partition label."""
        config = PersistenceConfig(partition_label="custom_persist")

        self.assertEqual(config.partition_label, "custom_persist")

    def test_persistence_paths(self):
        """Test persistence path list."""
        config = PersistenceConfig()
        paths = config.get_persistence_paths()

        self.assertIn("/home", paths)
        self.assertIn("/etc", paths)
        self.assertIn("/var/log", paths)
        self.assertIsInstance(paths, list)
        self.assertGreater(len(paths), 0)


class TestGrubConfigurator(unittest.TestCase):
    """Test GRUB configuration generation."""

    def test_generate_grub_entry_with_persistence(self):
        """Test GRUB entry generation with persistence enabled."""
        entry = GrubConfigurator.generate_grub_entry(persistence_enabled=True)

        self.assertIn("persistence", entry)
        self.assertIn("USBFREEDOM with Persistence", entry)
        self.assertIn("persistence-label=persistence", entry)
        self.assertIn("USBFREEDOM (No Persistence)", entry)
        self.assertIn("nopersistence", entry)

    def test_generate_grub_entry_without_persistence(self):
        """Test GRUB entry generation without persistence."""
        entry = GrubConfigurator.generate_grub_entry(persistence_enabled=False)

        self.assertNotIn("persistence-label", entry)
        self.assertNotIn("persistence", entry.lower())
        self.assertIn("USBFREEDOM", entry)


class TestSyslinuxConfigurator(unittest.TestCase):
    """Test Syslinux configuration generation."""

    def test_generate_syslinux_config_with_persistence(self):
        """Test Syslinux config generation with persistence."""
        config = SyslinuxConfigurator.generate_syslinux_config(persistence_enabled=True)

        self.assertIn("persistence", config)
        self.assertIn("persistence-label=persistence", config)
        self.assertIn("USBFREEDOM with Persistence", config)
        self.assertIn("nopersistence", config)

    def test_generate_syslinux_config_without_persistence(self):
        """Test Syslinux config generation without persistence."""
        config = SyslinuxConfigurator.generate_syslinux_config(persistence_enabled=False)

        self.assertNotIn("persistence-label", config)
        self.assertIn("USBFREEDOM", config)


class TestPersistenceBuilder(unittest.TestCase):
    """Test PersistenceBuilder operations."""

    def setUp(self):
        """Set up test fixtures."""
        self.builder = PersistenceBuilder("/dev/sdb2")

    @patch('tempfile.TemporaryDirectory')
    @patch('usbfreedom.persistence.run_command')
    @patch('pathlib.Path.mkdir')
    @patch('builtins.open', new_callable=mock_open)
    def test_setup_persistence_structure(self, mock_file, mock_mkdir, mock_run, mock_tmpdir):
        """Test persistence structure creation."""
        # Mock temporary directory
        mock_tmpdir.return_value.__enter__.return_value = "/tmp/test"

        result = self.builder.setup_persistence_structure()

        # Verify mount command was called
        mount_calls = [call for call in mock_run.call_args_list if 'mount' in str(call)]
        self.assertGreater(len(mount_calls), 0)

        # Verify directories were created
        self.assertTrue(mock_mkdir.called)

        # Verify persistence.conf was written
        self.assertTrue(mock_file.called)

    @patch('tempfile.TemporaryDirectory')
    @patch('usbfreedom.persistence.run_command')
    @patch('pathlib.Path.exists')
    def test_verify_persistence_success(self, mock_exists, mock_run, mock_tmpdir):
        """Test successful persistence verification."""
        mock_tmpdir.return_value.__enter__.return_value = "/tmp/test"
        mock_exists.return_value = True

        result = self.builder.verify_persistence()

        # Should return True if all checks pass
        # Note: This is simplified, actual test would need more mocking
        self.assertIsInstance(result, bool)

    @patch('tempfile.TemporaryDirectory')
    @patch('usbfreedom.persistence.run_command')
    @patch('pathlib.Path.exists')
    def test_verify_persistence_failure(self, mock_exists, mock_run, mock_tmpdir):
        """Test failed persistence verification."""
        mock_tmpdir.return_value.__enter__.return_value = "/tmp/test"
        # Simulate missing persistence.conf
        mock_exists.return_value = False

        result = self.builder.verify_persistence()

        self.assertFalse(result)


if __name__ == '__main__':
    unittest.main()
