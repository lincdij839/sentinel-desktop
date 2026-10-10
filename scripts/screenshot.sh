#!/usr/bin/env bash
# Capture a region, save it under Pictures/Screenshots, and copy it to the clipboard.
set -euo pipefail

pictures="${XDG_PICTURES_DIR:-$HOME/Pictures}"
dest="$pictures/Screenshots"
mkdir -p -- "$dest"
file="$dest/sentinel-$(date +%Y%m%d-%H%M%S).png"

notify() {
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        Sentinel 0 "" "$1" "$2" [] {} 4000 >/dev/null 2>&1 || true
}

if ! command -v slurp >/dev/null 2>&1 || ! command -v grim >/dev/null 2>&1; then
    notify "SCREENSHOT FAILED" "grim or slurp is not installed"
    exit 1
fi

if ! geometry="$(slurp)"; then
    exit 0
fi
if [[ -z $geometry ]]; then
    exit 0
fi
if ! grim -g "$geometry" "$file"; then
    notify "SCREENSHOT FAILED" "capture failed"
    exit 1
fi
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "$file" || true
fi
notify "SCREENSHOT" "$file"
