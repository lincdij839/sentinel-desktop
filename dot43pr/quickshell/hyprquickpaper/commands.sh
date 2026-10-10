#!/usr/bin/env bash
# Replace "random" with: fade, wipe, grow, outer, wave, center, any, random

img="$1"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

if command -v awww >/dev/null 2>&1; then
    awww img "$img" -t random --transition-duration 1 --resize fit
elif command -v swww >/dev/null 2>&1; then
    swww img "$img" --transition-type random --transition-duration 1 --resize fit
fi

mkdir -p "$HOME/.cache/43pr"
setsid -f python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$img" \
    >>"$HOME/.cache/43pr/theme.log" 2>&1
