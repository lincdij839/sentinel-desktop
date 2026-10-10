#!/usr/bin/env bash
# Pick a cliphist entry and copy it back. Opens a terminal when launched without a TTY.
set -euo pipefail

notify() {
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        Sentinel 0 "" "$1" "$2" [] {} 4000 >/dev/null 2>&1 || true
}

if ! command -v cliphist >/dev/null 2>&1 || ! command -v wl-copy >/dev/null 2>&1; then
    notify "CLIPBOARD" "cliphist or wl-clipboard is not installed"
    exit 1
fi

if [[ ! -t 0 ]]; then
    if command -v ptyxis >/dev/null 2>&1; then
        exec ptyxis --title Clipboard -- "$0"
    fi
    notify "CLIPBOARD" "no terminal available to pick a clip"
    exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
    notify "CLIPBOARD" "fzf is not installed"
    exit 1
fi

choice="$(cliphist list | fzf --prompt 'CLIP> ' --reverse)" || exit 0
if [[ -z $choice ]]; then
    exit 0
fi
printf '%s\n' "$choice" | cliphist decode | wl-copy
notify "CLIPBOARD" "copied"
