#!/usr/bin/env bash
# Stand up the lab update repository on this host: TLS, signed RPM,
# publish directory, HTTPS service, firewall for QEMU guests.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host_ip=192.168.122.1
if ip -4 addr show virbr0 >/dev/null 2>&1; then
    detected=$(ip -4 -o addr show virbr0 | awk '{print $4}' | cut -d/ -f1 | head -1)
    [[ -n $detected ]] && host_ip=$detected
fi
url="https://${host_ip}:8743/"
publish="$project_dir/publish/fedora/44"

err() { printf 'setup-lab-repo: %s\n' "$*" >&2; }

"$project_dir/rpm/generate-tls.sh" "$host_ip"
cat > "$project_dir/rpm/update.conf" <<EOF
# Lab update repository on this host. QEMU guests use the virbr0 address.
SENTINEL_REPO_URL=${url}
SENTINEL_REPO_PUBLISH=${publish}
EOF

export SENTINEL_REPO_URL=$url
export SENTINEL_REPO_PUBLISH=$publish
"$project_dir/rpm/build-repo.sh"
"$project_dir/rpm/publish.sh" --dir "$project_dir/repo" --dest "$publish"
cp -a -- "$project_dir/rpm/tls/ca.crt" "$publish/sentinel-repo-ca.crt"

unit=/etc/systemd/system/sentinel-repo.service
watch_unit=/etc/systemd/system/sentinel-auto-publish.service
if [[ $(id -u) -eq 0 ]]; then
    cp -- "$project_dir/rpm/sentinel-repo.service" "$unit"
    cp -- "$project_dir/rpm/sentinel-auto-publish.service" "$watch_unit"
    systemctl daemon-reload
    systemctl enable --now sentinel-repo.service
    systemctl enable --now sentinel-auto-publish.service
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --zone=libvirt --add-port=8743/tcp || true
        firewall-cmd --reload || true
    fi
else
    err "not root: start the repo with: sudo cp rpm/sentinel-repo.service $unit && sudo systemctl enable --now sentinel-repo.service sentinel-auto-publish.service"
fi
"$project_dir/rpm/auto-publish.sh" --remember

printf 'Lab repository: %s\n' "$url"
printf 'Clients: sudo sentinel-update (timer checks every 15 minutes)\n'
