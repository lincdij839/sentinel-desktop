#!/usr/bin/env bash
# Push this repo to already-installed Sentinel machines.
# One run updates what the user sees (/usr/share) and the on-disk source
# (/usr/src) together. It does not rebuild the ISO.
#
#   scripts/push-update.sh
#   scripts/push-update.sh yuan@192.168.122.34
#   SENTINEL_HOSTS='yuan@192.168.122.34 yuan@192.168.122.244' \
#   SENTINEL_SSH_PASS='…' scripts/push-update.sh
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
hosts=(${SENTINEL_HOSTS:-yuan@192.168.122.34 yuan@192.168.122.244})
if (($#)); then
    hosts=("$@")
fi

ssh_opts=(-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
ssh_cmd=(ssh "${ssh_opts[@]}")
scp_cmd=(scp "${ssh_opts[@]}")
if [[ -n ${SENTINEL_SSH_PASS:-} ]] && command -v sshpass >/dev/null 2>&1; then
    ssh_cmd=(sshpass -p "$SENTINEL_SSH_PASS" ssh "${ssh_opts[@]}"
        -o PreferredAuthentications=password -o PubkeyAuthentication=no)
    scp_cmd=(sshpass -p "$SENTINEL_SSH_PASS" scp "${ssh_opts[@]}"
        -o PreferredAuthentications=password -o PubkeyAuthentication=no)
fi

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
archive="$work/sentinel-src.zip"

python3 - "$project_dir" "$archive" << 'PY'
import pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
skip_dirs = {".git", "__pycache__", "vendor", ".qemu-nested"}
skip_suffix = {".iso", ".qcow2", ".pyc"}
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root)
        if any(part in skip_dirs for part in rel.parts):
            continue
        if path.suffix in skip_suffix:
            continue
        zf.write(path, rel.as_posix())
PY

for host in "${hosts[@]}"; do
    printf 'Pushing %s -> %s\n' "$project_dir" "$host"
    "${scp_cmd[@]}" "$archive" "$host:/tmp/sentinel-src.zip"
    {
        printf 'export SENTINEL_SSH_PASS=%q\n' "${SENTINEL_SSH_PASS:-}"
        printf 'export SENTINEL_SUDO_PASS=%q\n' "${SENTINEL_SUDO_PASS:-}"
        cat << 'REMOTE'
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
python3 - << 'PY'
import pathlib, zipfile
root = pathlib.Path("/tmp/sentinel-push")
zipfile.ZipFile("/tmp/sentinel-src.zip").extractall(root)
for path in root.rglob("*"):
    if path.suffix == ".sh" or path.name in {"install.sh", "sentinel-session", "sentinel-ctl", "sentinel-update", "sentinel-relabel"}:
        path.chmod(path.stat().st_mode | 0o111)
print("extracted", len(list(root.rglob("*"))))
PY
if [[ $(id -u) -eq 0 ]]; then
    bash /tmp/sentinel-push/install.sh --prefix /usr --sync
else
    pass=${SENTINEL_SUDO_PASS:-${SENTINEL_SSH_PASS:-}}
    if [[ -n $pass ]]; then
        printf '%s\n' "$pass" | sudo -S -p "" bash /tmp/sentinel-push/install.sh --prefix /usr --sync
    else
        sudo bash /tmp/sentinel-push/install.sh --prefix /usr --sync
    fi
fi
if [[ -d ${XDG_RUNTIME_DIR}/hypr ]]; then
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
    export HYPRLAND_INSTANCE_SIGNATURE="$(ls "$XDG_RUNTIME_DIR/hypr" | tail -1)"
    hyprctl dismissnotify >/dev/null 2>&1 || true
    # Config is already live from the atomic replace; only reload if Hyprland
    # still lists an error, then clear the leftover overlay.
    if [[ -n $(hyprctl configerrors 2>/dev/null) ]]; then
        hyprctl reload >/dev/null || true
        sleep 0.3
    fi
    hyprctl dismissnotify >/dev/null 2>&1 || true
    echo errors=[$(hyprctl configerrors 2>/dev/null)]
fi
REMOTE
    } | "${ssh_cmd[@]}" "$host" bash
done
printf 'Updated /usr/share/sentinel-desktop and /usr/src/sentinel-desktop on %s\n' "${hosts[*]}"
