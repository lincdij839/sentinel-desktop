#!/usr/bin/env bash
# Commands used by 43PR keybinds. Always run with a PATH that includes
# Fedora sbin, the qs wrapper, and the user's local bin.
set -euo pipefail

export PATH="${HOME:+$HOME/.local/bin:}/usr/local/bin:/usr/bin:/usr/sbin:/bin${PATH:+:$PATH}"

share="${SENTINEL_HOME:-/usr/share/sentinel-desktop}"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
qs_bin=
if command -v quickshell >/dev/null 2>&1; then
    qs_bin=$(command -v quickshell)
elif command -v qs >/dev/null 2>&1; then
    qs_bin=$(command -v qs)
fi

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a Sentinel "$@"
    fi
}

qs_ipc() {
    if [[ -z $qs_bin ]]; then
        notify "Quickshell is not installed"
        exit 1
    fi
    exec "$qs_bin" ipc call "$@"
}

pidfile=/tmp/sentinel-screen-record.pid

case ${1:-} in
    ipc)
        shift
        qs_ipc "$@"
        ;;
    launcher)
        if pgrep -x rofi >/dev/null; then
            exec pkill -x rofi
        fi
        exec rofi -show drun
        ;;
    clip)
        if pgrep -x rofi >/dev/null; then
            exec pkill -x rofi
        fi
        cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy
        ;;
    wallpaper)
        paper="$config/quickshell/hyprquickpaper"
        if [[ ! -f $paper/shell.qml ]]; then
            paper="$share/dot43pr/quickshell/hyprquickpaper"
        fi
        if [[ -z $qs_bin ]]; then
            notify "Quickshell is not installed"
            exit 1
        fi
        # The picker only lists files in Pictures/Wallpapers, not subfolders.
        walls="${HOME}/Pictures/Wallpapers"
        mkdir -p "$walls"
        if [[ -d $walls/43pr ]]; then
            shopt -s nullglob
            for img in "$walls/43pr"/*.{png,jpg,jpeg,webp,PNG,JPG,JPEG,WEBP}; do
                base="${img##*/}"
                if [[ ! -e $walls/$base ]]; then
                    ln -s "$img" "$walls/$base"
                fi
            done
            shopt -u nullglob
        fi
        uid=$(id -u)
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
        if [[ -z ${WAYLAND_DISPLAY:-} || ! -S $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY ]]; then
            for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
                [[ -S $sock ]] || continue
                export WAYLAND_DISPLAY="${sock##*/}"
                break
            done
        fi
        if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} && -d $XDG_RUNTIME_DIR/hypr ]]; then
            HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | tail -1)
            export HYPRLAND_INSTANCE_SIGNATURE
        fi
        # A leftover picker grabs the keyboard and the next Super+W never reaches Hyprland.
        pkill -f 'quickshell.*hyprquickpaper' >/dev/null 2>&1 || true
        mkdir -p "${HOME}/.cache/43pr"
        # -d also starts the default shell and duplicates the bar.
        setsid -f "$qs_bin" -p "$paper" >>"${HOME}/.cache/43pr/wallpaper-picker.log" 2>&1
        ;;
    theme)
        exec python3 "$config/43pr/bin/theme.py" toggle
        ;;
    opacity)
        exec "$config/hypr/scripts/opacity.sh"
        ;;
    lock)
        exec hyprlock
        ;;
    ime)
        if [[ -x $share/scripts/toggle-ime.sh ]]; then
            exec "$share/scripts/toggle-ime.sh"
        fi
        exec hyprctl switchxkblayout current next
        ;;
    screenshot)
        kind=${2:-full}
        mkdir -p "$HOME/Pictures"
        file="$HOME/Pictures/$(date +%s).png"
        if [[ $kind == area ]]; then
            grim -g "$(slurp)" "$file"
        else
            grim "$file"
        fi
        wl-copy < "$file"
        if [[ -n $qs_bin ]]; then
            "$qs_bin" ipc call screenshot notify "$file" || true
        fi
        ;;
    record)
        if [[ -f $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
            kill -INT "$(cat "$pidfile")" || true
            rm -f "$pidfile"
            notify "Recording saved"
            exit 0
        fi
        mkdir -p "$HOME/Videos"
        out="$HOME/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4"
        if command -v gpu-screen-recorder >/dev/null 2>&1; then
            output=$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; m=json.load(sys.stdin); print(m[0]["name"] if m else "eDP-1")' 2>/dev/null || printf 'eDP-1')
            gpu-screen-recorder -w "$output" -f 60 -a default_output -o "$out" &
            echo $! > "$pidfile"
            notify "Recording started"
            exit 0
        fi
        if command -v wf-recorder >/dev/null 2>&1; then
            wf-recorder -f "$out" &
            echo $! > "$pidfile"
            notify "Recording started"
            exit 0
        fi
        notify "No screen recorder installed"
        exit 1
        ;;
    exit-session)
        if command -v uwsm >/dev/null 2>&1; then
            exec uwsm stop
        fi
        if [[ -n ${XDG_SESSION_ID:-} ]]; then
            exec loginctl terminate-session "$XDG_SESSION_ID"
        fi
        exec loginctl terminate-user ""
        ;;
    -h|--help)
        printf 'Usage: %s {ipc|launcher|clip|wallpaper|theme|opacity|lock|ime|screenshot|record|exit-session}\n' "${0##*}"
        exit 0
        ;;
    *)
        printf '43pr-bind: unknown action: %s\n' "${1:-}" >&2
        exit 2
        ;;
esac
