#!/usr/bin/env bash
# Region capture, then annotate with swappy (Fedora-Hyprland uses the same grim/slurp/swappy path).
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

if ! command -v slurp >/dev/null 2>&1 || ! command -v grim >/dev/null 2>&1 || ! command -v swappy >/dev/null 2>&1; then
    notify "SCREENSHOT FAILED" "grim, slurp, or swappy is not installed"
    exit 1
fi

if ! geometry="$(slurp)"; then
    exit 0
fi
if [[ -z $geometry ]]; then
    exit 0
fi
if ! grim -g "$geometry" - | swappy -f - -o "$file"; then
    notify "SCREENSHOT FAILED" "annotate failed"
    exit 1
fi
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy < "$file" || true
fi
notify "SCREENSHOT" "$file"
