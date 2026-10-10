#!/usr/bin/env bash
# Sentinel release pipeline: build RPM → test as a QEMU client would →
# sign (done during build) → publish to the update repository.
#
#   rpm/release.sh
#   rpm/release.sh --skip-publish
#   rpm/release.sh --bump
#   SENTINEL_REPO_URL=https://updates.example.com/fedora/\$releasever/ \
#   SENTINEL_REPO_PUBLISH=/var/www/sentinel/fedora/44 \
#       rpm/release.sh
#
# Host edits are only development. This command is what makes a fix
# available to every client that can reach the repository.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
spec="$project_dir/rpm/sentinel-desktop.spec"
skip_test=0
skip_publish=0
bump=0

err() { printf 'release: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --skip-test) skip_test=1; shift ;;
        --skip-publish) skip_publish=1; shift ;;
        --bump) bump=1; shift ;;
        -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

if ((bump)); then
    current=$(awk '/^Release:/{print $2; exit}' "$spec")
    current=${current%%%*}
    next=$((current + 1))
    sed -i "s/^Release:        ${current}%{?dist}/Release:        ${next}%{?dist}/" "$spec"
    printf 'Bumped Release to %s\n' "$next"
fi

"$project_dir/rpm/build-repo.sh"
if ((skip_test == 0)); then
    "$project_dir/rpm/qemu-test-update.sh" --dir "$project_dir/repo"
fi
if ((skip_publish == 0)); then
    "$project_dir/rpm/publish.sh" --dir "$project_dir/repo"
fi
printf 'Release finished. Clients pick this up with: sudo sentinel-update\n'
