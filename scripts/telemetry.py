#!/usr/bin/env python3
"""Emit a short, read-only snapshot of Linux system metrics as JSON."""

import json
from pathlib import Path
import shutil
import sys
import time
from typing import Callable


def parse_cpu_stat(contents: str) -> tuple[int, int]:
    for line in contents.splitlines():
        fields = line.split()
        if fields and fields[0] == "cpu":
            values = [int(value) for value in fields[1:]]
            if len(values) < 4:
                break
            idle = values[3] + (values[4] if len(values) > 4 else 0)
            return sum(values), idle
    raise ValueError("Could not read aggregate CPU counters from /proc/stat")


def cpu_percent(before: tuple[int, int], after: tuple[int, int]) -> float:
    total_delta = after[0] - before[0]
    idle_delta = after[1] - before[1]
    if total_delta <= 0 or idle_delta < 0 or idle_delta > total_delta:
        raise ValueError("CPU counters did not advance consistently")
    return round(100 * (total_delta - idle_delta) / total_delta, 1)


def parse_memory(contents: str) -> tuple[int, int, float]:
    values: dict[str, int] = {}
    for line in contents.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0].endswith(":"):
            values[fields[0][:-1]] = int(fields[1])

    total_kib = values.get("MemTotal")
    available_kib = values.get("MemAvailable")
    if total_kib is None or available_kib is None or total_kib <= 0:
        raise ValueError("Could not read MemTotal and MemAvailable from /proc/meminfo")

    used_kib = max(0, total_kib - available_kib)
    return used_kib, total_kib, round(100 * used_kib / total_kib, 1)


def parse_network(contents: str) -> tuple[int, int]:
    received = 0
    transmitted = 0
    found_interface = False

    for line in contents.splitlines()[2:]:
        if ":" not in line:
            continue
        interface, counters = line.split(":", 1)
        if interface.strip() == "lo":
            continue
        values = counters.split()
        if len(values) < 9:
            continue
        received += int(values[0])
        transmitted += int(values[8])
        found_interface = True

    if not found_interface:
        return 0, 0
    return received, transmitted


def parse_loadavg(contents: str) -> tuple[float, float, float]:
    fields = contents.split()
    if len(fields) < 3:
        raise ValueError("Could not read load averages from /proc/loadavg")
    one, five, fifteen = (float(value) for value in fields[:3])
    return one, five, fifteen


def disk_usage(path: str = "/") -> tuple[int, int, float]:
    usage = shutil.disk_usage(path)
    if usage.total <= 0:
        raise ValueError(f"Could not read filesystem size for {path}")
    return usage.used, usage.total, round(100 * usage.used / usage.total, 1)


CPU_SENSOR_CHIPS = ("coretemp", "k10temp", "zenpower", "cpu_thermal", "acpitz")
PREFERRED_TEMP_LABELS = ("package", "composite", "tctl", "tdie")


def read_text(path: Path) -> str | None:
    try:
        return path.read_text().strip()
    except OSError:
        return None


def chip_temperature(chip: Path) -> float | None:
    readings: list[tuple[str, float]] = []
    for input_file in sorted(chip.glob("temp*_input")):
        raw = read_text(input_file)
        try:
            celsius = int(raw) / 1000 if raw is not None else None
        except ValueError:
            continue
        if celsius is None or not -50 <= celsius <= 150:
            continue
        label = (read_text(input_file.with_name(input_file.name.replace("_input", "_label"))) or "").lower()
        readings.append((label, celsius))
    if not readings:
        return None
    for label, celsius in readings:
        if label.startswith(PREFERRED_TEMP_LABELS):
            return round(celsius, 1)
    return round(max(celsius for _, celsius in readings), 1)


def read_temperatures(sys_root: Path = Path("/sys")) -> tuple[float | None, float | None]:
    """Return (cpu, storage) temperatures in Celsius, or None when not reported."""
    chips: dict[str, float] = {}
    for chip in sorted((sys_root / "class/hwmon").glob("hwmon*")):
        name = read_text(chip / "name")
        temperature = chip_temperature(chip)
        if name and temperature is not None:
            chips.setdefault(name, temperature)
    cpu = next((chips[name] for name in CPU_SENSOR_CHIPS if name in chips), None)
    return cpu, chips.get("nvme")


def read_battery(sys_root: Path = Path("/sys")) -> tuple[int, str] | None:
    for supply in sorted((sys_root / "class/power_supply").glob("*")):
        if read_text(supply / "type") != "Battery":
            continue
        try:
            percent = int(read_text(supply / "capacity") or "")
        except ValueError:
            continue
        if 0 <= percent <= 100:
            return percent, read_text(supply / "status") or "Unknown"
    return None


def snapshot(proc_root: Path = Path("/proc"), sample_interval: float = 0.2,
             sleep: Callable[[float], None] = time.sleep,
             disk_path: str = "/", sys_root: Path = Path("/sys")) -> dict[str, int | float | str | None]:
    cpu_before = parse_cpu_stat((proc_root / "stat").read_text())
    sleep(sample_interval)
    cpu_after = parse_cpu_stat((proc_root / "stat").read_text())
    memory_used_kib, memory_total_kib, memory_percent = parse_memory(
        (proc_root / "meminfo").read_text()
    )
    received, transmitted = parse_network((proc_root / "net/dev").read_text())
    uptime_seconds = int(float((proc_root / "uptime").read_text().split()[0]))
    load_1, load_5, load_15 = parse_loadavg((proc_root / "loadavg").read_text())
    disk_used, disk_total, disk_percent_used = disk_usage(disk_path)
    cpu_temp, storage_temp = read_temperatures(sys_root)
    battery = read_battery(sys_root)

    return {
        "cpu_percent": cpu_percent(cpu_before, cpu_after),
        "memory_percent": memory_percent,
        "memory_used_mib": round(memory_used_kib / 1024),
        "memory_total_mib": round(memory_total_kib / 1024),
        "rx_bytes": received,
        "tx_bytes": transmitted,
        "uptime_seconds": uptime_seconds,
        "load_1": load_1,
        "load_5": load_5,
        "load_15": load_15,
        "disk_used_gib": round(disk_used / 1024**3, 1),
        "disk_total_gib": round(disk_total / 1024**3, 1),
        "disk_percent": disk_percent_used,
        "cpu_temp_c": cpu_temp,
        "storage_temp_c": storage_temp,
        "battery_percent": battery[0] if battery else None,
        "battery_status": battery[1] if battery else None,
    }


def main() -> int:
    try:
        print(json.dumps(snapshot(), separators=(",", ":")))
    except (OSError, ValueError, IndexError) as error:
        print(f"telemetry: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
