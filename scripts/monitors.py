#!/usr/bin/env python3
"""Read and update ~/.config/sentinel/monitors.conf (name and scale per line)."""

import json
import os
import sys
from pathlib import Path


def config_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "sentinel" / "monitors.conf"


def parse_scales(text: str) -> dict[str, float]:
    scales: dict[str, float] = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        try:
            value = float(parts[1])
        except ValueError:
            continue
        if 0.5 <= value <= 3:
            scales[parts[0]] = value
    return scales


def format_scales(scales: dict[str, float]) -> str:
    lines = [f"{name} {scales[name]:g}" for name in sorted(scales)]
    return ("\n".join(lines) + "\n") if lines else ""


def load() -> dict[str, float]:
    path = config_path()
    if not path.is_file():
        return {}
    return parse_scales(path.read_text())


def save(scales: dict[str, float]) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(format_scales(scales))


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "get"
    if command == "get":
        print(json.dumps({"error": "", "scales": load()}))
        return 0
    if command == "set" and len(sys.argv) == 4:
        name = sys.argv[2]
        try:
            value = float(sys.argv[3])
        except ValueError:
            value = 0
        if not name or any(char.isspace() for char in name) or not 0.5 <= value <= 3:
            print(json.dumps({"error": "REFUSED", "scales": load()}))
            return 0
        scales = load()
        scales[name] = value
        save(scales)
        print(json.dumps({"error": "", "scales": scales}))
        return 0
    print(json.dumps({"error": "USAGE", "scales": {}}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
