#!/usr/bin/env bash
# Prepare a user home for the Sentinel 43PR desktop. Safe to run on every login.
# Root: set up every /home/* account. A regular user: set up $HOME only.
set -euo pipefail

share="${SENTINEL_HOME:-/usr/share/sentinel-desktop}"
rice="$share/dot43pr"

# Files theme.py / opacity.sh overwrite. Copy once so /usr/share stays read-only.
GENERATED_FILES=(
    kitty/matugen.conf
    hypr/hyprlock-colors.conf
    hypr/rules.lua
    gtk-3.0/colors.css
    gtk-4.0/colors.css
    gtk-3.0/settings.ini
    gtk-4.0/settings.ini
    rofi/colors.rasi
    quickshell/Theme.qml
)

is_generated() {
    local rel=$1 g
    for g in "${GENERATED_FILES[@]}"; do
        [[ $rel == "$g" ]] && return 0
    done
    return 1
}

same_link() {
    local path=$1 want=$2
    [[ -L $path && $(readlink -n -- "$path") == "$want" ]]
}

write_app_env() {
    local dest=$1
    cat > "$dest" <<'EOF'
# Toolkit backends for apps launched from the desktop.
# GTK keeps an X11 fallback; Firefox and Electron skip the XWayland probe.
GDK_BACKEND=wayland,x11
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=auto
QT_QPA_PLATFORM=wayland;xcb
EOF
}

owned_by_root() {
    local path=$1
    [[ -e $path ]] || return 1
    [[ $(stat -c %u -- "$path") -eq 0 ]]
}

already_ready() {
    local home=$1
    same_link "$home/.local/bin/qs" "$share/scripts/start-qs.sh" || return 1
    [[ -e $home/.config/fcitx5/profile ]] || return 1
    [[ -f $home/.config/environment.d/50-sentinel-apps.conf ]] || return 1
    [[ -d $home/Pictures/Wallpapers ]] || return 1
    [[ -e $home/Pictures/Wallpapers/43pr ]] || return 1
    owned_by_root "$home/.cache/43pr" && return 1
    owned_by_root "$home/.local" && return 1
    owned_by_root "$home/.local/state" && return 1
    if [[ -f $rice/quickshell/shell.qml ]]; then
        same_link "$home/.config/quickshell/shell.qml" "$rice/quickshell/shell.qml" || return 1
        same_link "$home/.config/quickshell/Wheel.qml" "$rice/quickshell/Wheel.qml" || return 1
        same_link "$home/.config/quickshell/Notifications.qml" "$rice/quickshell/Notifications.qml" || return 1
        same_link "$home/.config/quickshell/KeybindList.qml" "$rice/quickshell/KeybindList.qml" || return 1
        same_link "$home/.config/hypr/keybinds.lua" "$rice/hypr/keybinds.lua" || return 1
        [[ -e $home/.config/43pr/bin/theme.py ]] || return 1
    fi
    return 0
}

repair_home_tree() {
    local home=$1 user=$2 as_owner=$3
    if ((as_owner)); then
        install -d -o "$user" -g "$user" \
            "$home/.config" "$home/.local" "$home/.local/bin" \
            "$home/.local/state" "$home/.local/state/43pr" \
            "$home/.cache" "$home/.cache/43pr" \
            "$home/.config/environment.d" \
            "$home/Pictures" "$home/Pictures/Wallpapers"
        local p
        for p in "$home/.local" "$home/.cache" "$home/.cache/43pr" \
                 "$home/.local/state" "$home/.local/state/43pr"; do
            if owned_by_root "$p"; then
                chown -R "$user:$user" "$p" || true
            fi
        done
        chown "$user:$user" "$home/Pictures" "$home/Desktop" 2>/dev/null || true
    else
        mkdir -p "$home/.config" "$home/.local/bin" "$home/.local/state/43pr" \
            "$home/.cache/43pr" "$home/.config/environment.d" \
            "$home/Pictures/Wallpapers"
    fi
}

link_rice() {
    local home=$1 user=$2 as_owner=$3
    [[ -d $rice/quickshell ]] || return 0
    local dest
    # .lian used to replace these with a single directory symlink.
    # Individual 43PR files cannot be linked through that.
    for dest in quickshell hypr kitty matugen rofi 43pr gtk-3.0 gtk-4.0; do
        dest="$home/.config/$dest"
        if [[ -L $dest ]]; then
            rm -f -- "$dest"
        fi
    done
    local src rel
    while IFS= read -r -d '' src; do
        rel=${src#"$rice"/}
        case $rel in
            SOURCE.txt|LICENSE|README.md|.zshrc) continue ;;
        esac
        dest="$home/.config/$rel"
        mkdir -p -- "$(dirname -- "$dest")"
        if is_generated "$rel"; then
            if [[ -L $dest ]]; then
                rm -f -- "$dest"
            fi
            if [[ ! -e $dest ]]; then
                cp -a -- "$src" "$dest"
                if ((as_owner)); then
                    chown "$user:$user" "$dest" || true
                fi
            fi
        else
            if [[ -e $dest && ! -L $dest ]]; then
                rm -f -- "$dest"
            fi
            ln -sfn "$src" "$dest"
            if ((as_owner)); then
                chown -h "$user:$user" "$dest" || true
            fi
        fi
    done < <(find "$rice" -type f -print0)
}

seed_wallpapers() {
    local home=$1 user=$2 as_owner=$3
    mkdir -p -- "$home/Pictures/Wallpapers"
    if ((as_owner)); then
        chown "$user:$user" "$home/Pictures" "$home/Pictures/Wallpapers" 2>/dev/null || true
    fi
    if [[ -d $share/assets/wallpapers/43pr && ! -e $home/Pictures/Wallpapers/43pr ]]; then
        ln -sfn "$share/assets/wallpapers/43pr" "$home/Pictures/Wallpapers/43pr"
        ((as_owner)) && chown -h "$user:$user" "$home/Pictures/Wallpapers/43pr" || true
    fi
    if [[ -d $share/assets/wallpapers && ! -e $home/Pictures/Wallpapers/sentinel ]]; then
        ln -sfn "$share/assets/wallpapers" "$home/Pictures/Wallpapers/sentinel"
        ((as_owner)) && chown -h "$user:$user" "$home/Pictures/Wallpapers/sentinel" || true
    fi
}

setup_fcitx() {
    local home=$1 user=$2 as_owner=$3
    local fcitx_src="$share/session/fcitx5"
    [[ -d $fcitx_src ]] || return 0
    mkdir -p -- "$home/.config/fcitx5/conf"
    if [[ ! -e $home/.config/fcitx5/config ]]; then
        cp -a -- "$fcitx_src/config" "$home/.config/fcitx5/config"
    fi
    if [[ ! -e $home/.config/fcitx5/profile ]]; then
        cp -a -- "$fcitx_src/profile" "$home/.config/fcitx5/profile"
    fi
    if [[ ! -e $home/.config/fcitx5/conf/pinyin.conf ]]; then
        cp -a -- "$fcitx_src/conf/pinyin.conf" "$home/.config/fcitx5/conf/pinyin.conf"
    fi
    if ((as_owner)); then
        chown -R "$user:$user" "$home/.config/fcitx5"
    fi
}

setup_one() {
    local home=$1 user=$2
    [[ -d $home ]] || return 0
    [[ $user != root ]] || return 0

    rm -f -- "$home/.lian" "$home/.local/bin/qshell"
    rm -rf -- "$home/.config/lianwall" "$home/Pictures/lianwall" "$home/Videos/lianwall"

    if already_ready "$home"; then
        return 0
    fi

    local as_owner=0
    if [[ $(id -u) -eq 0 ]] && getent passwd "$user" >/dev/null; then
        as_owner=1
    fi
    repair_home_tree "$home" "$user" "$as_owner"

    if [[ -x $share/scripts/start-qs.sh ]]; then
        ln -sfn "$share/scripts/start-qs.sh" "$home/.local/bin/qs"
        ((as_owner)) && chown -h "$user:$user" "$home/.local/bin/qs" || true
    fi

    link_rice "$home" "$user" "$as_owner"
    seed_wallpapers "$home" "$user" "$as_owner"
    setup_fcitx "$home" "$user" "$as_owner"
    if [[ -f $rice/.zshrc ]]; then
        ln -sfn "$rice/.zshrc" "$home/.zshrc"
        ((as_owner)) && chown -h "$user:$user" "$home/.zshrc" || true
    fi

    local envd="$home/.config/environment.d/50-sentinel-apps.conf"
    if [[ ! -f $envd ]]; then
        write_app_env "$envd"
        if ((as_owner)); then
            chown "$user:$user" "$envd"
        fi
    fi

    if [[ -x $home/.config/43pr/bin/theme.py ]] && command -v python3 >/dev/null 2>&1; then
        local theme_cmd=apply
        [[ -f $home/.local/state/43pr/state.json ]] || theme_cmd=default
        HOME="$home" XDG_CONFIG_HOME="$home/.config" \
            XDG_CACHE_HOME="$home/.cache" XDG_STATE_HOME="$home/.local/state" \
            python3 "$home/.config/43pr/bin/theme.py" "$theme_cmd" >/dev/null 2>&1 || true
        if ((as_owner)); then
            chown -R "$user:$user" "$home/.cache/43pr" "$home/.local/state/43pr" \
                2>/dev/null || true
        fi
    fi
}

if (($# >= 2)); then
    setup_one "$1" "$2"
elif [[ $(id -u) -eq 0 ]]; then
    for home in /home/*; do
        [[ -d $home ]] || continue
        setup_one "$home" "$(stat -c %U "$home")"
    done
else
    setup_one "${HOME}" "$(id -un)"
fi
