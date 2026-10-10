#!/usr/bin/env bash
# Run the Sentinel desktop as a nested Hyprland window inside the current
# Wayland session. Nothing outside this checkout is modified.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf '%s\n' "run-nested.sh needs a running Wayland session to nest inside." >&2
    exit 1
fi

for command in Hyprland quickshell; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command" >&2
        exit 1
    fi
done

export SENTINEL_HOME="$project_dir"
if [[ -z "${DBUS_SESSION_BUS_ADDRESS_SENTINEL:-}" ]]; then
    # Private bus so our notification server doesn't fight the host desktop's.
    export DBUS_SESSION_BUS_ADDRESS_SENTINEL=1
    exec dbus-run-session -- "$0" "$@"
fi
exec Hyprland --config "$project_dir/session/hyprland.lua"
