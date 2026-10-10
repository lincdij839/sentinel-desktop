#!/usr/bin/env python3
"""Copy, move, delete, and list removable places for the file panel."""

import json
import os
import shutil
import sys
from pathlib import Path


def emit(payload: dict) -> int:
    print(json.dumps(payload))
    return 0


def real(path: str) -> Path:
    return Path(os.path.realpath(os.path.expanduser(path)))


def refuse_root(path: Path) -> str:
    home = Path.home()
    if path == Path("/"):
        return "REFUSED ROOT"
    if path == home:
        return "REFUSED HOME"
    return ""


def places() -> list[dict]:
    found = [{"name": "HOME", "path": str(Path.home()), "kind": "PLACE"}]
    seen = {str(Path.home())}
    uid = os.getuid()
    prefixes = (
        "/run/media/",
        "/media/",
        f"/run/user/{uid}/gvfs",
        "/mnt/",
    )
    try:
        lines = Path("/proc/mounts").read_text().splitlines()
    except OSError:
        return found
    for line in lines:
        parts = line.split()
        if len(parts) < 2:
            continue
        target = parts[1].replace("\\040", " ")
        if not target.startswith(prefixes):
            continue
        path = Path(target)
        if not path.is_dir() or str(path) in seen:
            continue
        seen.add(str(path))
        found.append({"name": path.name or str(path), "path": str(path), "kind": "MOUNT"})
    return found


def transfer(kind: str, source: str, dest_dir: str) -> dict:
    src = real(source)
    dest_root = real(dest_dir)
    if not src.exists():
        return {"error": "MISSING", "path": str(dest_root)}
    if not dest_root.is_dir():
        return {"error": "NOT A DIRECTORY", "path": str(dest_root)}
    dest = dest_root / src.name
    if dest.exists():
        return {"error": "EXISTS", "path": str(dest)}
    if dest == src or dest.is_relative_to(src):
        return {"error": "REFUSED INSIDE", "path": str(dest)}
    try:
        if kind == "copy":
            if src.is_dir():
                shutil.copytree(src, dest, symlinks=True)
            else:
                shutil.copy2(src, dest, follow_symlinks=False)
        else:
            shutil.move(src, dest)
    except OSError as error:
        return {"error": error.strerror or "FAILED", "path": str(dest_root)}
    return {"error": "", "path": str(dest_root), "result": str(dest)}


def delete(target: str) -> dict:
    path = real(target)
    refused = refuse_root(path)
    if refused:
        return {"error": refused, "path": str(path)}
    if not path.exists():
        return {"error": "MISSING", "path": str(path)}
    for place in places():
        if place["kind"] == "MOUNT" and path == Path(place["path"]):
            return {"error": "REFUSED MOUNT", "path": str(path)}
    try:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
    except OSError as error:
        return {"error": error.strerror or "FAILED", "path": str(path)}
    return {"error": "", "path": str(path.parent), "result": path.name}


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "places":
        return emit({"error": "", "places": places()})
    if command in ("copy", "move") and len(sys.argv) == 4:
        return emit(transfer(command, sys.argv[2], sys.argv[3]))
    if command == "delete" and len(sys.argv) == 3:
        return emit(delete(sys.argv[2]))
    return emit({"error": "USAGE", "path": ""})


if __name__ == "__main__":
    raise SystemExit(main())
