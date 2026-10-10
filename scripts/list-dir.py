#!/usr/bin/env python3
"""List one directory as JSON for the Sentinel file panel. Read-only."""

import json
import os
import stat
import sys


def main() -> int:
    raw = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~")
    show_hidden = "--hidden" in sys.argv[2:]
    path = os.path.abspath(os.path.expanduser(raw))
    if not os.path.isdir(path):
        print(json.dumps({"path": path, "error": "NOT A DIRECTORY", "entries": []}))
        return 0

    entries = []
    try:
        names = os.listdir(path)
    except OSError as error:
        print(json.dumps({"path": path, "error": error.strerror or "UNREADABLE", "entries": []}))
        return 0

    for name in names:
        if name in (".", "..") or (not show_hidden and name.startswith(".")):
            continue
        full = os.path.join(path, name)
        try:
            info = os.lstat(full)
            is_dir = os.path.isdir(full)
        except OSError:
            continue
        if stat.S_ISLNK(info.st_mode):
            kind = "LINK"
        elif stat.S_ISDIR(info.st_mode):
            kind = "DIR"
        elif stat.S_ISREG(info.st_mode):
            kind = "FILE"
        else:
            kind = "SPECIAL"
        entries.append({"name": name, "dir": is_dir, "kind": kind, "size": info.st_size})

    entries.sort(key=lambda item: (not item["dir"], item["name"].casefold()))
    print(json.dumps({"path": path, "error": "", "entries": entries[:400]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
