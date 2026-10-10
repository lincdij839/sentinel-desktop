#!/usr/bin/env bash
# Toggle fcitx5 between English and pinyin. Bound to Ctrl+Space.
set -euo pipefail

if ! command -v fcitx5-remote >/dev/null 2>&1; then
    exit 0
fi

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send --app-name=Sentinel --expire-time=1500 -- "$1" "$2" || true
}

name="$(fcitx5-remote -n 2>/dev/null || true)"
if [[ $name == pinyin ]]; then
    fcitx5-remote -c || true
    busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetCurrentIM s keyboard-us >/dev/null 2>&1 || true
    notify "输入法" "英文"
else
    busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetCurrentIM s pinyin >/dev/null 2>&1 || true
    fcitx5-remote -s pinyin || true
    fcitx5-remote -o || true
    notify "输入法" "拼音"
fi
