#!/usr/bin/env bash
# Poll the desktop tree and publish a new lab RPM when it changes.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
while true; do
    "$project_dir/rpm/auto-publish.sh" || true
    sleep 15
done
