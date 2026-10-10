#!/usr/bin/env bash
# Install Fedora packages used by the 43PR Hyprland + Quickshell rice.
# https://github.com/43PR/dotfiles
set -euo pipefail

prefix=/usr
while (($#)); do
    case $1 in
        --prefix) prefix=${2:?--prefix needs a directory}; shift 2 ;;
        -h|--help) printf 'Usage: %s [--prefix DIR]\n' "${0##*/}" >&2; exit 0 ;;
        *) printf 'Usage: %s [--prefix DIR]\n' "${0##*/}" >&2; exit 2 ;;
    esac
done
prefix="${prefix%/}"

if [[ $(id -u) -ne 0 && $prefix == /usr ]]; then
    printf 'install-43pr: needs root (sudo %s)\n' "${BASH_SOURCE[0]}" >&2
    exit 2
fi

dnf_install() {
    local extra=(--skip-unavailable)
    if dnf install -y --setopt=install_weak_deps=False "${extra[@]}" "$@"; then
        return 0
    fi
    dnf install -y --nogpgcheck --setopt=install_weak_deps=False "${extra[@]}" \
        --disablerepo='*' \
        --repofrompath=ustc-fedora,https://mirrors.ustc.edu.cn/fedora/releases/44/Everything/x86_64/os/ \
        --repofrompath=ustc-updates,https://mirrors.ustc.edu.cn/fedora/updates/44/Everything/x86_64/ \
        --repofrompath=copr-hyprland,https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-44-x86_64/ \
        --enablerepo=ustc-fedora,ustc-updates,copr-hyprland \
        "$@"
}

if command -v dnf >/dev/null 2>&1; then
    dnf_install rofi hyprlock hyprpolkitagent network-manager-applet blueman \
        ImageMagick papirus-icon-theme adw-gtk3-theme gnome-themes-extra \
        gammastep cava jq eza google-roboto-mono-fonts jetbrains-mono-fonts-all \
        kitty swww matugen brightnessctl playerctl cliphist pavucontrol \
        grim slurp wl-clipboard thunar \
        google-noto-sans-cjk-fonts google-noto-color-emoji-fonts \
        || printf 'install-43pr: some desktop packages were not installed\n' >&2
    # Optional names differ across Fedora and COPR. Do not fail the batch.
    dnf_install starship fontawesome-fonts fontawesome-6-free-fonts \
        fontawesome4-fonts nwg-look || true
    dnf_install awww || true
fi

if [[ -x $prefix/share/sentinel-desktop/scripts/setup-user.sh ]]; then
    "$prefix/share/sentinel-desktop/scripts/setup-user.sh" || true
fi

printf '43PR desktop packages checked for prefix %s\n' "$prefix"
