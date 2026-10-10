#!/usr/bin/env bash
# Create a local CA and server certificate for the lab HTTPS repository.
# Keys stay in rpm/tls/ and are not committed.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tls="$project_dir/rpm/tls"
host_ip=${1:-192.168.122.1}

mkdir -p -- "$tls"
if [[ ! -f $tls/ca.crt || ! -f $tls/ca.key ]]; then
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
        -keyout "$tls/ca.key" -out "$tls/ca.crt" \
        -subj "/CN=Sentinel Update CA"
fi
if [[ -f $tls/server.crt && -f $tls/server.key ]] \
    && openssl x509 -noout -checkend 86400 -in "$tls/server.crt" >/dev/null 2>&1 \
    && openssl x509 -noout -text -in "$tls/server.crt" | grep -q "IP Address:${host_ip}"; then
    printf 'TLS already valid in %s for %s\n' "$tls" "$host_ip"
    exit 0
fi
cat > "$tls/server.ext" <<EOF
subjectAltName = IP:${host_ip},DNS:updates.sentinel.local,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF
openssl req -newkey rsa:2048 -nodes \
    -keyout "$tls/server.key" -out "$tls/server.csr" \
    -subj "/CN=updates.sentinel.local"
openssl x509 -req -in "$tls/server.csr" \
    -CA "$tls/ca.crt" -CAkey "$tls/ca.key" -CAcreateserial \
    -out "$tls/server.crt" -days 3650 -extfile "$tls/server.ext"
chmod 600 -- "$tls/ca.key" "$tls/server.key"
printf 'Wrote TLS material in %s for %s\n' "$tls" "$host_ip"
