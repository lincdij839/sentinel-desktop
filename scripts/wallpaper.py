#!/usr/bin/env python3
"""List and cycle Sentinel wallpapers. Choice is stored in ~/.config/sentinel/wallpaper."""

import json
import os
import sys
from pathlib import Path

SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def sentinel_home() -> Path:
    override = os.environ.get("SENTINEL_HOME")
    if override:
        return Path(override)
    return Path(__file__).resolve().parents[1]


def config_home() -> Path:
    override = os.environ.get("XDG_CONFIG_HOME")
    if override:
        return Path(override)
    return Path.home() / ".config"


def choice_file() -> Path:
    return config_home() / "sentinel" / "wallpaper"


def library() -> list[Path]:
    roots = [
        sentinel_home() / "assets" / "wallpapers",
        config_home() / "sentinel" / "wallpapers",
    ]
    found: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.iterdir(), key=lambda item: item.name.casefold()):
            if not path.is_file() or path.suffix.lower() not in SUFFIXES:
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            found.append(resolved)
    if found:
        return found
    fallback = (sentinel_home() / "assets" / "wallpaper.png").resolve()
    return [fallback] if fallback.is_file() else []


def current() -> Path | None:
    path = choice_file()
    if path.is_file():
        chosen = Path(path.read_text().strip())
        if chosen.is_file():
            return chosen.resolve()
    items = library()
    return items[0] if items else None


def write_choice(path: Path) -> None:
    destination = choice_file()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(str(path.resolve()) + "\n")


def emit(payload: dict) -> int:
    print(json.dumps(payload))
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "current"
    items = library()
    if command == "list":
        chosen = current()
        return emit({
            "error": "" if items else "NO WALLPAPER",
            "current": str(chosen) if chosen else "",
            "wallpapers": [str(item) for item in items],
        })
    if command == "current":
        chosen = current()
        if chosen is None:
            return emit({"error": "NO WALLPAPER", "path": ""})
        return emit({"error": "", "path": str(chosen)})
    if command == "next":
        if not items:
            return emit({"error": "NO WALLPAPER", "path": ""})
        chosen = current()
        try:
            index = items.index(chosen) if chosen else -1
        except ValueError:
            index = -1
        nxt = items[(index + 1) % len(items)]
        write_choice(nxt)
        return emit({"error": "", "path": str(nxt), "count": len(items)})
    return emit({"error": "USAGE", "path": ""})


if __name__ == "__main__":
    raise SystemExit(main())
