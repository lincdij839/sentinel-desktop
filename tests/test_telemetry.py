import tempfile
import unittest
from pathlib import Path

from scripts.telemetry import (
    cpu_percent,
    disk_usage,
    parse_cpu_stat,
    parse_loadavg,
    parse_memory,
    parse_network,
    read_battery,
    read_temperatures,
)


class TelemetryParsingTests(unittest.TestCase):
    def test_cpu_percent_uses_idle_and_iowait_counters(self) -> None:
        before = parse_cpu_stat("cpu 100 0 50 800 50 0 0 0 0 0\n")
        after = parse_cpu_stat("cpu 200 0 100 850 50 0 0 0 0 0\n")

        self.assertEqual(cpu_percent(before, after), 75.0)

    def test_cpu_percent_rejects_non_advancing_counters(self) -> None:
        with self.assertRaises(ValueError):
            cpu_percent((100, 50), (100, 50))

    def test_memory_uses_available_memory(self) -> None:
        contents = "MemTotal: 1000 kB\nMemAvailable: 250 kB\n"

        self.assertEqual(parse_memory(contents), (750, 1000, 75.0))

    def test_network_ignores_loopback(self) -> None:
        contents = (
            "Inter-| Receive | Transmit\n"
            " face |bytes packets errs drop fifo frame compressed multicast|"
            "bytes packets errs drop fifo colls carrier compressed\n"
            "  lo: 999 0 0 0 0 0 0 0 888 0 0 0 0 0 0 0\n"
            "eth0: 123 0 0 0 0 0 0 0 456 0 0 0 0 0 0 0\n"
        )

        self.assertEqual(parse_network(contents), (123, 456))

    def test_loadavg_reads_three_averages(self) -> None:
        self.assertEqual(parse_loadavg("0.52 0.48 0.40 1/700 12345\n"), (0.52, 0.48, 0.40))

    def test_loadavg_rejects_short_input(self) -> None:
        with self.assertRaises(ValueError):
            parse_loadavg("0.52 0.48\n")

    def test_disk_usage_reports_consistent_percentage(self) -> None:
        used, total, percent = disk_usage("/")

        self.assertGreater(total, 0)
        self.assertLessEqual(used, total)
        self.assertAlmostEqual(percent, round(100 * used / total, 1), places=1)


class SensorTests(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.root = Path(self._dir.name)

    def write(self, relative: str, contents: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)

    def test_temperatures_prefer_package_label_and_nvme_chip(self) -> None:
        self.write("class/hwmon/hwmon0/name", "coretemp\n")
        self.write("class/hwmon/hwmon0/temp1_input", "70000\n")
        self.write("class/hwmon/hwmon0/temp1_label", "Core 0\n")
        self.write("class/hwmon/hwmon0/temp2_input", "55500\n")
        self.write("class/hwmon/hwmon0/temp2_label", "Package id 0\n")
        self.write("class/hwmon/hwmon1/name", "nvme\n")
        self.write("class/hwmon/hwmon1/temp1_input", "41000\n")

        self.assertEqual(read_temperatures(self.root), (55.5, 41.0))

    def test_temperatures_ignore_missing_or_implausible_readings(self) -> None:
        self.write("class/hwmon/hwmon0/name", "k10temp\n")
        self.write("class/hwmon/hwmon0/temp1_input", "-999999\n")
        self.write("class/hwmon/hwmon1/name", "nvme\n")
        self.write("class/hwmon/hwmon1/temp1_input", "not-a-number\n")

        self.assertEqual(read_temperatures(self.root), (None, None))
        self.assertEqual(read_temperatures(self.root / "absent"), (None, None))

    def test_battery_skips_mains_and_reads_capacity(self) -> None:
        self.write("class/power_supply/ADP0/type", "Mains\n")
        self.write("class/power_supply/BAT0/type", "Battery\n")
        self.write("class/power_supply/BAT0/capacity", "87\n")
        self.write("class/power_supply/BAT0/status", "Discharging\n")

        self.assertEqual(read_battery(self.root), (87, "Discharging"))

    def test_battery_absent_returns_none(self) -> None:
        self.write("class/power_supply/ADP0/type", "Mains\n")

        self.assertIsNone(read_battery(self.root))


if __name__ == "__main__":
    unittest.main()
