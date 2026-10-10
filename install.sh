#!/usr/bin/env bash
# Install the Sentinel Wayland session so it appears in the login screen.
#
#   ./install.sh [--prefix DIR] [--dry-run] [--sync] [--full] [--extras]
#   ./install.sh --uninstall [--prefix DIR]
#
# The default prefix is /usr (needs root); use --prefix "$HOME/.local" for a
# per-user layout (display managers only list it if XDG_DATA_DIRS includes it).
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
prefix=/usr
dry_run=0
uninstall=0
sync_only=0
full_extras=0
payload=(shell dashboard scripts assets session dot43pr)
# Full tree kept on disk so a later repair does not need the ISO.
source_items=(shell dashboard scripts assets session dot43pr image tests install.sh README.md run-nested.sh run-demo.sh rpm)
if [[ -d $project_dir/vendor ]]; then
    payload+=(vendor)
    source_items+=(vendor)
fi

extras_only=0

usage() {
    printf 'Usage: %s [--prefix DIR] [--dry-run] [--sync] [--full] [--extras] [--uninstall]\n' "${0##*/}" >&2
}

while (($#)); do
    case $1 in
        --prefix) prefix=${2:?--prefix needs a directory}; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --sync) sync_only=1; shift ;;
        --full) full_extras=1; shift ;;
        --extras) extras_only=1; shift ;;
        --uninstall) uninstall=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

prefix="${prefix%/}"
share_dir="$prefix/share/sentinel-desktop"
src_dir=/usr/src/sentinel-desktop
bin_link="$prefix/bin/sentinel-session"
ctl_link="$prefix/bin/sentinel-ctl"
update_link="$prefix/bin/sentinel-update"
session_file="$prefix/share/wayland-sessions/sentinel.desktop"
relabel_unit="$prefix/lib/systemd/system/sentinel-relabel.service"

# Replace an existing file by rename so Hyprland never sees a missing
# hyprland.lua (cp unlinks first and the compositor draws a red bar).
copy_file() {
    local src=$1 dest=$2
    local tmp=${dest}.new
    if ((dry_run)); then
        printf '+ install %s -> %s\n' "$src" "$dest"
        return
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    cp -a --no-preserve=context -- "$src" "$tmp"
    mv -f -- "$tmp" "$dest"
}

copy_items() {
    local dest=$1
    shift
    run mkdir -p -- "$dest"
    local item src path rel
    for item in "$@"; do
        src="$project_dir/$item"
        if [[ -d $src ]]; then
            run mkdir -p -- "$dest/$item"
            if ((dry_run)); then
                printf '+ copy tree %s -> %s\n' "$src" "$dest/$item"
                continue
            fi
            while IFS= read -r -d '' path; do
                rel=${path#"$src"/}
                [[ $rel != "$path" ]] || continue
                if [[ -d $path && ! -L $path ]]; then
                    mkdir -p -- "$dest/$item/$rel"
                elif [[ -L $path ]]; then
                    rm -f -- "$dest/$item/$rel"
                    cp -a --no-preserve=context -- "$path" "$dest/$item/$rel"
                elif [[ -f $path ]]; then
                    copy_file "$path" "$dest/$item/$rel"
                fi
            done < <(find "$src" -print0)
        elif [[ -e $src ]]; then
            copy_file "$src" "$dest/$item"
        fi
    done
}

run() {
    if ((dry_run)); then
        printf '+ %s\n' "$*"
    else
        "$@"
    fi
}

install_extras() {
    local force=${1:-0}
    local scripts=$share_dir/scripts
    [[ -x $scripts/install-43pr.sh ]] || scripts=$project_dir/scripts
    if [[ $prefix != /usr ]] || ((dry_run)) || [[ $(id -u) -ne 0 ]]; then
        return 0
    fi
    if [[ -x $scripts/install-43pr.sh ]]; then
        "$scripts/install-43pr.sh" --prefix "$prefix" || true
    fi
}

# cp -a keeps the source SELinux label. A theme copied from /tmp or /home then
# stays user_tmp_t, and SDDM (sddm_t) can stat Main.qml but cannot list the
# directory. Qt reports that as "File name case mismatch".
publish() {
    local src=$1 dest=$2
    run rm -rf -- "$dest"
    run cp -a --no-preserve=context -- "$src" "$dest"
    if [[ $prefix == /usr ]]; then
        run chmod -R a+rX -- "$dest"
        if command -v restorecon >/dev/null 2>&1; then
            run restorecon -RF -- "$dest" || true
        fi
    fi
}

if ((uninstall)); then
    run rm -f -- "$bin_link" "$ctl_link" "$update_link" "$session_file"
    run rm -f -- "$relabel_unit"
    if [[ $prefix == /usr ]] && command -v systemctl >/dev/null 2>&1; then
        run systemctl disable sentinel-relabel.service || true
    fi
    run rm -rf -- "$share_dir"
    if [[ $prefix == /usr ]]; then
        run rm -f -- /usr/lib/systemd/logind.conf.d/50-sentinel.conf
        run rm -f -- /etc/sddm.conf.d/10-sentinel.conf
        run rm -rf -- /usr/share/sddm/themes/sentinel /usr/share/sddm/themes/sddm-astronaut-theme /usr/share/sentinel-desktop/lian
    fi
    exit 0
fi

if ((extras_only)); then
    if [[ $prefix != /usr ]] || [[ $(id -u) -ne 0 ]]; then
        printf 'install.sh --extras needs root and --prefix /usr\n' >&2
        exit 2
    fi
    install_extras 1
    printf 'Sentinel extras installed under %s\n' "$prefix"
    exit 0
fi

for command in Hyprland quickshell python3; do
    command -v "$command" >/dev/null 2>&1 || printf 'warning: %s is not installed\n' "$command" >&2
done

run mkdir -p -- "$share_dir" "$prefix/bin" "$prefix/share/wayland-sessions"
# Copy over the live tree. Do not delete hyprland.lua or the PAM file first:
# Hyprland and the lock screen keep those paths open.
copy_items "$share_dir" "${payload[@]}"
run find "$share_dir" -name __pycache__ -type d -prune -exec rm -rf {} +
run rm -rf -- "$share_dir/lian" "$share_dir/phantomat" "$share_dir/vendor/coucou"
run rm -f -- "$prefix/bin/lianwall" "$prefix/bin/lianwalld" "$prefix/bin/lianwall-gui"
if [[ $prefix == /usr ]]; then
    run rm -rf -- /usr/share/sddm/themes/sddm-astronaut-theme
    run chmod -R a+rX -- "$share_dir"
    if command -v restorecon >/dev/null 2>&1; then
        run restorecon -RF -- "$share_dir" || true
    fi
    # qsl icons are Material Symbols ligatures. Without this font the
    # power rail shows clipped names like "logostout" / "estart_al".
    if [[ -d $share_dir/assets/fonts ]]; then
        run mkdir -p -- /usr/share/fonts/sentinel
        run cp -a --no-preserve=context -- "$share_dir/assets/fonts/." /usr/share/fonts/sentinel/
        run chmod -R a+rX -- /usr/share/fonts/sentinel
        if command -v restorecon >/dev/null 2>&1; then
            run restorecon -RF -- /usr/share/fonts/sentinel || true
        fi
        if command -v fc-cache >/dev/null 2>&1; then
            run fc-cache -f -- /usr/share/fonts/sentinel || true
        fi
    fi
    # Keep a complete source tree for repair without the installer disc.
    if [[ $(readlink -f -- "$project_dir") != "$(readlink -f -- "$src_dir" 2>/dev/null || true)" ]]; then
        copy_items "$src_dir" "${source_items[@]}"
        run find "$src_dir" -name __pycache__ -type d -prune -exec rm -rf {} +
        run chmod -R a+rX -- "$src_dir"
        if command -v restorecon >/dev/null 2>&1; then
            run restorecon -RF -- "$src_dir" || true
        fi
    fi
fi
run ln -sf -- "$share_dir/session/sentinel-session" "$bin_link"
run ln -sf -- "$share_dir/session/sentinel-ctl" "$ctl_link"
# Keep a real file in /usr/bin so updating the share tree cannot delete this command.
run rm -f -- "$update_link"
run cp -a --no-preserve=context -- "$project_dir/session/sentinel-update" "$update_link"
run chmod 755 -- "$update_link"
if [[ $prefix == /usr ]]; then
    run mkdir -p -- /usr/lib/systemd/system
    run cp -a --no-preserve=context -- "$project_dir/session/sentinel-relabel.service" "$relabel_unit"
    run chmod 644 -- "$relabel_unit"
    if command -v restorecon >/dev/null 2>&1; then
        run restorecon -F -- "$relabel_unit" || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        run systemctl enable sentinel-relabel.service
    fi
    if [[ -f $project_dir/session/sentinel-update.timer ]]; then
        run cp -a --no-preserve=context -- \
            "$project_dir/session/sentinel-update.service" \
            /usr/lib/systemd/system/sentinel-update.service
        run cp -a --no-preserve=context -- \
            "$project_dir/session/sentinel-update.timer" \
            /usr/lib/systemd/system/sentinel-update.timer
        if command -v systemctl >/dev/null 2>&1; then
            run systemctl enable sentinel-update.timer
        fi
    fi
    if [[ -f $project_dir/rpm/update.conf ]]; then
        run mkdir -p -- /etc/sentinel
        run cp -a --no-preserve=context -- "$project_dir/rpm/update.conf" /etc/sentinel/update.conf
    fi
fi
if [[ $prefix == /usr ]]; then
    run mkdir -p -- /usr/lib/systemd/logind.conf.d /etc/sddm.conf.d /usr/share/sddm/themes
    publish "$project_dir/session/logind-lid.conf" /usr/lib/systemd/logind.conf.d/50-sentinel.conf
    publish "$project_dir/session/sddm/10-sentinel.conf" /etc/sddm.conf.d/10-sentinel.conf
    publish "$project_dir/session/sddm/sentinel" /usr/share/sddm/themes/sentinel
    # Drop stock greeters and leftover .lian astronaut theme. Keep Sentinel.
    if ((dry_run)); then
        printf '+ rm -rf -- /usr/share/sddm/themes/<not sentinel or astronaut>\n'
    else
        shopt -s nullglob
        for theme_dir in /usr/share/sddm/themes/*; do
            [[ -e $theme_dir ]] || continue
            case ${theme_dir##*/} in
                sentinel) continue ;;
            esac
            rm -rf -- "$theme_dir"
        done
        shopt -u nullglob
    fi
fi

if ((dry_run)); then
    printf '+ write %s (Exec=%s)\n' "$session_file" "$bin_link"
else
    sed "s|^Exec=.*|Exec=$bin_link|" "$project_dir/session/sentinel.desktop" > "$session_file"
    if [[ $prefix == /usr ]] && command -v restorecon >/dev/null 2>&1; then
        restorecon -F -- "$session_file" "$bin_link" "$ctl_link" || true
    fi
fi
if [[ $prefix == /usr ]] && ((dry_run == 0)); then
    # The astronaut greeter lists every .desktop here. Stock Hyprland would
    # start without Sentinel's config, shell, or wallpaper.
    run mkdir -p -- /usr/share/wayland-sessions/stock
    for extra in hyprland.desktop hyprland-uwsm.desktop; do
        if [[ -f /usr/share/wayland-sessions/$extra ]]; then
            run mv -f -- "/usr/share/wayland-sessions/$extra" "/usr/share/wayland-sessions/stock/$extra"
        fi
    done
    if [[ -f /var/lib/sddm/state.conf ]]; then
        run sed -i 's|^Session=.*|Session=/usr/share/wayland-sessions/sentinel.desktop|' /var/lib/sddm/state.conf
    fi
fi
# First install compiles extras. A later sentinel-update only needs them
# when --full is passed; otherwise skip so a bugfix takes seconds.
if ((sync_only == 0)); then
    install_extras 0
fi
printf 'Sentinel session installed under %s\n' "$prefix"
