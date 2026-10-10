#!/usr/bin/env python3
"""List and change saved NetworkManager connections, including VPN."""

import json
import shutil
import subprocess
import sys


def split_nmcli(line: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    escaped = False
    for char in line.rstrip("\n"):
        if escaped:
            buf.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            parts.append("".join(buf))
            buf = []
        else:
            buf.append(char)
    parts.append("".join(buf))
    return parts


def parse_connections(saved_text: str, active_text: str) -> list[dict]:
    active = set()
    for line in active_text.splitlines():
        if not line.strip():
            continue
        fields = split_nmcli(line)
        if fields and fields[0]:
            active.add(fields[0])
    items = []
    for line in saved_text.splitlines():
        if not line.strip():
            continue
        fields = split_nmcli(line)
        if len(fields) < 2 or not fields[0]:
            continue
        kind = fields[1]
        items.append({
            "name": fields[0],
            "type": kind,
            "vpn": "vpn" in kind or kind in ("wireguard", "tun", "vpn"),
            "active": fields[0] in active,
        })
    items.sort(key=lambda item: (not item["active"], item["name"].casefold()))
    return items


def emit(payload: dict) -> int:
    print(json.dumps(payload))
    return 0


def nmcli(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["nmcli", *args], capture_output=True, text=True)


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    if shutil.which("nmcli") is None:
        return emit({"error": "NO NETWORKMANAGER", "connections": []})
    if command == "list":
        saved = nmcli("-t", "-f", "NAME,TYPE", "connection", "show")
        active = nmcli("-t", "-f", "NAME", "connection", "show", "--active")
        if saved.returncode != 0:
            message = (saved.stderr or saved.stdout).strip() or "NMCLI FAILED"
            return emit({"error": message, "connections": []})
        return emit({
            "error": "",
            "connections": parse_connections(saved.stdout, active.stdout),
        })
    if command in ("up", "down", "delete") and len(sys.argv) == 3:
        name = sys.argv[2]
        if not name or name.startswith("-"):
            return emit({"error": "REFUSED", "connections": []})
        verb = {"up": "up", "down": "down", "delete": "delete"}[command]
        result = nmcli("connection", verb, name)
        if result.returncode != 0:
            message = (result.stderr or result.stdout).strip() or "NMCLI FAILED"
            return emit({"error": message, "connections": []})
        return emit({"error": "", "status": command.upper() + " " + name, "connections": []})
    return emit({"error": "USAGE", "connections": []})


if __name__ == "__main__":
    raise SystemExit(main())
