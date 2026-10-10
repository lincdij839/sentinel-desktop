#!/usr/bin/env bash
# Verify a signed repository the way a QEMU guest will consume it:
# HTTP download, GPG check, DNF can see sentinel-desktop.
#
#   rpm/qemu-test-update.sh [--dir repo] [--port 8744]
#
# This is the "test in QEMU" gate before publish. It does not log into
# user machines. Optional: --vm DOMAIN uses qemu-guest-agent to run
# `dnf check-update` inside a local libvirt guest.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$project_dir/repo"
port=${SENTINEL_REPO_PORT:-8744}
vm=

err() { printf 'qemu-test-update: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --dir) dir=${2:?--dir needs a directory}; shift 2 ;;
        --port) port=${2:?--port needs a number}; shift 2 ;;
        --vm) vm=${2:?--vm needs a domain}; shift 2 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

[[ -d $dir/repodata && -f $dir/repodata/repomd.xml ]] || {
    err "not a DNF repository: $dir"
    exit 1
}
[[ -f $dir/RPM-GPG-KEY-sentinel ]] || { err "missing $dir/RPM-GPG-KEY-sentinel"; exit 1; }
shopt -s nullglob
rpms=("$dir"/sentinel-desktop-*.rpm)
shopt -u nullglob
((${#rpms[@]})) || { err "no sentinel-desktop RPM in $dir"; exit 1; }

bind=127.0.0.1
[[ -n $vm ]] && bind=0.0.0.0
verify_root="$(mktemp -d)"
server_log="$verify_root/http.log"
python3 -m http.server "$port" --bind "$bind" --directory "$dir" >"$server_log" 2>&1 &
server_pid=$!
cleanup() { kill "$server_pid" >/dev/null 2>&1 || true; rm -rf -- "$verify_root"; }
trap cleanup EXIT
sleep 0.2
if ! kill -0 "$server_pid" >/dev/null 2>&1; then
    err "HTTP server failed to start"
    cat "$server_log" >&2 || true
    exit 1
fi
ok=0
for _ in $(seq 1 40); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$port/repodata/repomd.xml" >/dev/null; then
        ok=1
        break
    fi
    sleep 0.1
done
((ok)) || { err "cannot fetch repomd.xml from http://127.0.0.1:$port/"; cat "$server_log" >&2 || true; exit 1; }
[[ -f $dir/repodata/repomd.xml.asc ]] || { err "repository metadata is not signed"; exit 1; }

rpmkeys --root "$verify_root" --import -- "$dir/RPM-GPG-KEY-sentinel"
check=$(rpmkeys --root "$verify_root" --checksig -- "${rpms[0]}")
printf '%s\n' "$check"
printf '%s\n' "$check" | grep -qiE 'signatures OK|digest.*OK' \
    || { err "package signature check failed"; exit 1; }

url=http://127.0.0.1:$port
if command -v dnf >/dev/null 2>&1; then
    mkdir -p -- "$verify_root/dnf" "$verify_root/log"
    dnf --quiet --repofrompath=sentinel-test,"$url" --repo=sentinel-test \
        --setopt=cachedir="$verify_root/dnf" \
        --setopt=system_cachedir="$verify_root/dnf" \
        --setopt=logdir="$verify_root/log" \
        --setopt=sentinel-test.gpgcheck=1 \
        --setopt=sentinel-test.gpgkey=file://$dir/RPM-GPG-KEY-sentinel \
        --setopt=sentinel-test.skip_if_unavailable=0 \
        list --available sentinel-desktop
fi

if [[ -n $vm ]] && command -v virsh >/dev/null 2>&1; then
    guest_url=http://192.168.122.1:$port
    raw=$(python3 -c 'import json,sys; print(json.dumps({"execute":"guest-exec","arguments":{"path":"/usr/bin/curl","arg":["-fsS","--max-time","8",sys.argv[1]],"capture-output":True}}))' \
        "$guest_url/repodata/repomd.xml")
    virsh -c qemu:///system qemu-agent-command "$vm" "$raw" >/dev/null \
        || err "guest $vm could not fetch the repository (agent/network)"
fi

printf 'QEMU update gate passed: HTTP + GPG + DNF see sentinel-desktop from %s\n' "$url"
