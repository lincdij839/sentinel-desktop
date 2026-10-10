#!/usr/bin/env bash
# Start awww or swww and paint a wallpaper so the first login is not empty.
set -euo pipefail

share="${SENTINEL_HOME:-/usr/share/sentinel-desktop}"
home="${HOME:-}"
walls="$home/Pictures/Wallpapers"

pick_image() {
    local f dir
    shopt -s nullglob
    for dir in "$walls/43pr" "$share/assets/wallpapers/43pr" "$walls"; do
        [[ -d $dir ]] || continue
        for f in "$dir"/*.{png,jpg,jpeg,webp,PNG,JPG,JPEG,WEBP}; do
            [[ -f $f ]] || continue
            printf '%s\n' "$f"
            shopt -u nullglob
            return 0
        done
    done
    shopt -u nullglob
    return 1
}

img=$(pick_image || true)

if command -v awww >/dev/null 2>&1; then
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
        sleep 0.2
    fi
    if [[ -n ${img:-} ]]; then
        awww img "$img" --resize fit >/dev/null 2>&1 || true
    fi
    exit 0
fi

if command -v swww >/dev/null 2>&1; then
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        swww-daemon --no-cache >/dev/null 2>&1 &
        for _ in 1 2 3 4 5; do
            swww query >/dev/null 2>&1 && break
            sleep 0.1
        done
    fi
    if [[ -n ${img:-} ]]; then
        swww img "$img" --resize fit >/dev/null 2>&1 || true
    fi
fi
