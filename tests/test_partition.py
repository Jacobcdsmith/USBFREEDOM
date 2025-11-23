"""Tests for partition management."""
import unittest
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
from usbfreedom.partition import PartitionManager, PartitionScheme, DeviceInfo, list_usb_devices


class TestPartitionScheme(unittest.TestCase):
    """Test PartitionScheme calculations."""

    def test_calculate_sizes_with_specific_persistence(self):
        """Test partition size calculation with specific persistence size."""
        scheme = PartitionScheme(boot_size_mb=2000, persistence_size_mb=4000)
        total_size = 8 * 1024 * 1024 * 1024  # 8GB

        boot_bytes, persist_bytes = scheme.calculate_sizes(total_size)

        self.assertEqual(boot_bytes, 2000 * 1024 * 1024)
        self.assertEqual(persist_bytes, 4000 * 1024 * 1024)

    def test_calculate_sizes_with_remaining_space(self):
        """Test partition size calculation using all remaining space."""
        scheme = PartitionScheme(boot_size_mb=2000, persistence_size_mb=-1)
        total_size = 8 * 1024 * 1024 * 1024  # 8GB

        boot_bytes, persist_bytes = scheme.calculate_sizes(total_size)

        self.assertEqual(boot_bytes, 2000 * 1024 * 1024)
        # Should use remaining space minus 100MB buffer
        expected_persist = total_size - boot_bytes - (100 * 1024 * 1024)
        self.assertEqual(persist_bytes, expected_persist)


class TestDeviceInfo(unittest.TestCase):
    """Test DeviceInfo dataclass."""

    def test_size_gb_conversion(self):
        """Test size conversion to GB."""
        device = DeviceInfo(
            path="/dev/sdb",
            size_bytes=8 * 1024 * 1024 * 1024,  # 8GB
            vendor="SanDisk",
            model="Ultra",
            removable=True
        )

        self.assertAlmostEqual(device.size_gb, 8.0, places=1)

    def test_str_representation(self):
        """Test string representation."""
        device = DeviceInfo(
            path="/dev/sdb",
            size_bytes=8 * 1024 * 1024 * 1024,
            vendor="SanDisk",
            model="Ultra",
            removable=True
        )

        str_repr = str(device)
        self.assertIn("/dev/sdb", str_repr)
        self.assertIn("SanDisk", str_repr)
        self.assertIn("Ultra", str_repr)


class TestPartitionManager(unittest.TestCase):
    """Test PartitionManager operations."""

    @patch('subprocess.run')
    def test_is_block_device(self, mock_run):
        """Test block device detection."""
        mock_run.return_value = Mock(returncode=0)

        pm = PartitionManager("/dev/sdb")
        # Constructor calls _is_block_device, so if we get here it passed

        mock_run.assert_called()

    def test_get_partition_path_standard(self):
        """Test partition path generation for standard devices."""
        pm = PartitionManager.__new__(PartitionManager)
        pm.device_path = "/dev/sdb"

        self.assertEqual(pm._get_partition_path(1), "/dev/sdb1")
        self.assertEqual(pm._get_partition_path(2), "/dev/sdb2")

    def test_get_partition_path_nvme(self):
        """Test partition path generation for NVMe devices."""
        pm = PartitionManager.__new__(PartitionManager)
        pm.device_path = "/dev/nvme0n1"

        self.assertEqual(pm._get_partition_path(1), "/dev/nvme0n1p1")
        self.assertEqual(pm._get_partition_path(2), "/dev/nvme0n1p2")

    def test_get_partition_path_mmc(self):
        """Test partition path generation for MMC devices."""
        pm = PartitionManager.__new__(PartitionManager)
        pm.device_path = "/dev/mmcblk0"

        self.assertEqual(pm._get_partition_path(1), "/dev/mmcblk0p1")
        self.assertEqual(pm._get_partition_path(2), "/dev/mmcblk0p2")


if __name__ == '__main__':
    unittest.main()
