#!/usr/bin/env bash
# Wallpaper daemon, clipboard, polkit, tray, and IME for the 43PR rice.
set -euo pipefail

share="${SENTINEL_HOME:-/usr/share/sentinel-desktop}"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd \
        WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SENTINEL_HOME \
        QT_QPA_PLATFORM GDK_BACKEND MOZ_ENABLE_WAYLAND \
        ELECTRON_OZONE_PLATFORM_HINT >/dev/null 2>&1 || true
fi

if command -v nm-applet >/dev/null 2>&1 && ! pgrep -x nm-applet >/dev/null 2>&1; then
    nm-applet >/dev/null 2>&1 &
fi
if command -v blueman-applet >/dev/null 2>&1 && ! pgrep -x blueman-applet >/dev/null 2>&1; then
    blueman-applet >/dev/null 2>&1 &
fi

if command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
    if ! pgrep -f 'wl-paste --type text --watch cliphist store' >/dev/null 2>&1; then
        wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
    fi
    if ! pgrep -f 'wl-paste --type image --watch cliphist store' >/dev/null 2>&1; then
        wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
    fi
fi

start_polkit() {
    local agent
    for agent in \
        /usr/libexec/hyprpolkitagent \
        /usr/bin/hyprpolkitagent \
        /usr/libexec/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-kde-authentication-agent-1
    do
        if [[ -x $agent ]] && ! pgrep -f "$agent" >/dev/null 2>&1; then
            "$agent" >/dev/null 2>&1 &
            return
        fi
    done
}
start_polkit

"$share/scripts/start-43pr-wallpaper.sh" || true

if [[ -x $share/session/start-fcitx.sh ]]; then
    "$share/session/start-fcitx.sh" || true
fi
