#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if command -v quickshell >/dev/null 2>&1; then
    quickshell_command="$(command -v quickshell)"
else
    printf '%s\n' "Quickshell not found. Install it with: sudo dnf install quickshell" >&2
    exit 1
fi

exec "$quickshell_command" --path "$project_dir/dashboard/Main.qml"
