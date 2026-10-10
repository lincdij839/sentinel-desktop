#!/usr/bin/env bash
# Serve the signed DNF repository so QEMU guests can pull an update.
#
#   rpm/serve-repo.sh [--port 8744] [--dir repo] [--https]
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
port=${SENTINEL_REPO_PORT:-8744}
dir="$project_dir/repo"
https=0

err() { printf 'serve-repo: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --port) port=${2:?--port needs a number}; shift 2 ;;
        --dir) dir=${2:?--dir needs a directory}; shift 2 ;;
        --https) https=1; port=${SENTINEL_REPO_PORT:-8743}; shift ;;
        -h|--help) sed -n '2,7p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

[[ -d $dir/repodata ]] || { err "not a DNF repository: $dir"; exit 1; }
command -v python3 >/dev/null 2>&1 || { err "missing python3"; exit 1; }

if ((https)); then
    [[ -f $project_dir/rpm/tls/server.crt && -f $project_dir/rpm/tls/server.key ]] || {
        err "run rpm/generate-tls.sh first"
        exit 1
    }
    printf 'Serving %s on https://0.0.0.0:%s/ (QEMU: https://192.168.122.1:%s/)\n' \
        "$dir" "$port" "$port"
    exec python3 "$project_dir/rpm/https-server.py" \
        --dir "$dir" --port "$port" --bind 0.0.0.0 \
        --cert "$project_dir/rpm/tls/server.crt" \
        --key "$project_dir/rpm/tls/server.key"
fi
printf 'Serving %s on http://0.0.0.0:%s/ (QEMU: http://192.168.122.1:%s/)\n' \
    "$dir" "$port" "$port"
exec python3 -m http.server "$port" --bind 0.0.0.0 --directory "$dir"
