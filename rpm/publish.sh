#!/usr/bin/env bash
# Publish a signed repository so clients can download it over HTTPS.
#
#   rpm/publish.sh [--dir repo] [--dest DIR|user@host:PATH]
#
# Destination comes from --dest, then SENTINEL_REPO_PUBLISH, then
# rpm/update.conf, then publish/fedora/<releasever>/ in this tree.
# The web server in front of that directory is what users reach.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$project_dir/repo"
dest=${SENTINEL_REPO_PUBLISH:-}

err() { printf 'publish: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --dir) dir=${2:?--dir needs a directory}; shift 2 ;;
        --dest) dest=${2:?--dest needs a path}; shift 2 ;;
        -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

[[ -d $dir/repodata ]] || { err "not a DNF repository: $dir"; exit 1; }

if [[ -z $dest && -f $project_dir/rpm/update.conf ]]; then
    dest=$(awk -F= '$1=="SENTINEL_REPO_PUBLISH"{sub(/^[^=]*=/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}' \
        "$project_dir/rpm/update.conf")
fi
if [[ -z $dest ]]; then
    ver=$(rpm -E '%fedora' 2>/dev/null || printf '44')
    [[ $ver == %fedora ]] && ver=44
    dest="$project_dir/publish/fedora/$ver"
fi

if [[ $dest == *:* && $dest != /* ]]; then
    command -v rsync >/dev/null 2>&1 || { err "rsync is required for $dest"; exit 1; }
    rsync -a --delete -- "$dir"/ "$dest"/
else
    mkdir -p -- "$dest"
    rm -rf -- "$dest/repodata"
    cp -a -- "$dir"/. "$dest"/
fi
if [[ -f $project_dir/rpm/install-latest.sh && $dest == /* ]]; then
    cp -a -- "$project_dir/rpm/install-latest.sh" "$dest/install-latest.sh"
    chmod 755 -- "$dest/install-latest.sh"
fi
printf 'Published signed repository to %s\n' "$dest"
printf 'Point HTTPS at that directory, then users run: sudo sentinel-update\n'
