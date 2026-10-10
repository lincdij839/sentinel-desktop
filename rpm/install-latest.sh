#!/usr/bin/env bash
# Install the newest signed Sentinel RPM without DNF.
# Python 3.14 rejects the lab CA, so this uses curl (-k fallback).
#   curl -kfsS https://192.168.122.1:8743/install-latest.sh | sudo bash
set -euo pipefail

url=${SENTINEL_REPO_URL:-https://192.168.122.1:8743/}
url=${url%/}
ca=/etc/pki/ca-trust/source/anchors/sentinel-repo-ca.crt
key=/etc/pki/rpm-gpg/RPM-GPG-KEY-sentinel
[[ -f $ca ]] || ca=

if [[ $(id -u) -ne 0 ]]; then
    exec sudo -- "$0" "$@"
fi

fetch() {
    local dest=$1
    shift
    if [[ -n $ca ]]; then
        curl -fsS --noproxy '*' --max-time 60 --cacert "$ca" -o "$dest" "$@" \
            || curl -kfsS --noproxy '*' --max-time 60 -o "$dest" "$@"
    else
        curl -kfsS --noproxy '*' --max-time 60 -o "$dest" "$@"
    fi
}

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
fetch "$work/repomd.xml" -- "$url/repodata/repomd.xml"
primary=$(python3 - "$work/repomd.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"m": "http://linux.duke.edu/metadata/repo"}
for data in ET.parse(sys.argv[1]).getroot().findall("m:data", ns):
    if data.get("type") == "primary":
        loc = data.find("m:location", ns)
        if loc is not None and loc.get("href"):
            print(loc.get("href"))
            raise SystemExit(0)
raise SystemExit("no primary metadata")
PY
)
fetch "$work/primary" -- "$url/$primary"
if [[ $primary == *.gz ]]; then
    gzip -dc -- "$work/primary" > "$work/primary.xml"
else
    mv -- "$work/primary" "$work/primary.xml"
fi
href=$(python3 - "$work/primary.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ns = {"p": "http://linux.duke.edu/metadata/common"}
best = None
for package in ET.parse(sys.argv[1]).getroot().findall("p:package", ns):
    name = package.find("p:name", ns)
    if name is not None and name.text == "sentinel-desktop":
        loc = package.find("p:location", ns)
        if loc is not None and loc.get("href"):
            best = loc.get("href")
if not best:
    raise SystemExit("no sentinel-desktop package")
print(best)
PY
)
rpm_file="$work/${href##*/}"
fetch "$rpm_file" -- "$url/$href"
if [[ -f $key ]]; then
    rpm --import -- "$key" || true
fi
rpm --checksig -- "$rpm_file"
rpm -Uvh -- "$rpm_file"
if [[ -x /usr/share/sentinel-desktop/scripts/setup-user.sh ]]; then
    /usr/share/sentinel-desktop/scripts/setup-user.sh || true
fi
shopt -s nullglob
for runtime in /run/user/*; do
    user=$(stat -c %U -- "$runtime" 2>/dev/null || true)
    [[ -n $user && $user != root && -d $runtime/hypr ]] || continue
    wayland=wayland-1
    [[ -S $runtime/$wayland ]] || wayland=wayland-0
    [[ -S $runtime/$wayland ]] || continue
    sig=$(ls "$runtime/hypr" 2>/dev/null | tail -1)
    [[ -n $sig ]] || continue
    sudo -u "$user" env \
        XDG_RUNTIME_DIR="$runtime" \
        WAYLAND_DISPLAY="$wayland" \
        HYPRLAND_INSTANCE_SIGNATURE="$sig" \
        SENTINEL_HOME=/usr/share/sentinel-desktop \
        bash -c '
            hyprctl dismissnotify >/dev/null 2>&1 || true
            hyprctl reload >/dev/null 2>&1 || true
            pkill -u "$(id -un)" -x quickshell || true
            pkill -u "$(id -un)" -x qs || true
            sleep 0.3
            hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"/usr/share/sentinel-desktop/scripts/start-qs.sh --path $HOME/.config/quickshell\"))" >/dev/null 2>&1 || true
        ' || true
done
shopt -u nullglob
printf 'Installed %s. If the top bar is unchanged, log out and back in.\n' "$href"
