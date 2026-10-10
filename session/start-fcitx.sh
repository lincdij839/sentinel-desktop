#!/usr/bin/env bash
# Install the Sentinel fcitx5 profile on first login, then start fcitx5 if present.
set -euo pipefail

self="$(readlink -f -- "${BASH_SOURCE[0]}")"
home="${SENTINEL_HOME:-$(dirname -- "$(dirname -- "$self")")}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dir="$config_root/fcitx5"

copy_missing() {
    local source=$1
    local target=$2
    if [[ -d $source ]]; then
        mkdir -p -- "$target"
        local child
        for child in "$source"/*; do
            [[ -e $child ]] || continue
            copy_missing "$child" "$target/$(basename -- "$child")"
        done
        return
    fi
    if [[ ! -e $target ]]; then
        cp -a -- "$source" "$target"
    fi
}

mkdir -p -- "$config_dir"
for source in "$home"/session/fcitx5/*; do
    [[ -e $source ]] || continue
    copy_missing "$source" "$config_dir/$(basename -- "$source")"
done

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
    local_display=
    for socket in wayland-1 wayland-0; do
        if [[ -S $runtime/$socket ]]; then
            local_display=$socket
            break
        fi
    done
    if [[ -n $local_display ]]; then
        export WAYLAND_DISPLAY=$local_display
    fi
fi
export DISPLAY="${DISPLAY:-:0}"

if command -v fcitx5 >/dev/null 2>&1; then
    if [[ ${1:-} == --foreground ]]; then
        exec fcitx5 --replace
    fi
    exec fcitx5 -d --replace
fi
