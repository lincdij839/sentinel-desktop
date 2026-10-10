#!/usr/bin/env bash
# Start qsl. NVIDIA needs the single-thread Qt scene graph; everyone else
# keeps the default threaded loop so the launcher and dock stay responsive.
set -euo pipefail

# ~/.local/bin/qs points here so the bar can find it. Clicks run
# `qs ipc call ...`; those must reach Quickshell, not start another bar.
qs_real=$(command -v quickshell || true)
if [[ -z ${qs_real} && -x /usr/bin/quickshell ]]; then
    qs_real=/usr/bin/quickshell
fi
case ${1:-} in
    ipc|log|list|kill|msg)
        if [[ -z ${qs_real} ]]; then
            printf 'start-qs: quickshell is not installed\n' >&2
            exit 1
        fi
        exec "$qs_real" "$@"
        ;;
esac

# Threaded Qt rendering stalls on llvmpipe (typical KVM guest). NVIDIA also
# needs the basic loop. Real GPUs keep the threaded renderer.
if [[ -e /dev/nvidia0 ]] || { command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -q; }; then
    export QSG_RENDER_LOOP=basic
else
    unset QSG_RENDER_LOOP
fi

# One bar. A second quickshell, even with no --path, draws another copy.
# Match the process name only. The config path contains "quickshell", and
# matching that string makes this script treat itself as an already-running bar.
# The wallpaper picker is a separate process and is left alone.
mapfile -t bars < <(ps -u "$(id -u)" -o pid=,comm=,args= | awk '$2 == "quickshell" && $0 !~ /hyprquickpaper/ {print $1}' | sort -n || true)
if ((${#bars[@]} > 1)); then
    kill "${bars[@]:1}" 2>/dev/null || true
fi
if ((${#bars[@]} >= 1)); then
    exit 0
fi
export MALLOC_CONF="${MALLOC_CONF:-background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000}"

if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -n "$@"
fi
if [[ -x /usr/bin/quickshell ]]; then
    exec /usr/bin/quickshell -n "$@"
fi
printf 'start-qs: quickshell is not installed\n' >&2
exit 1
