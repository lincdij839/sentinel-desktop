#!/usr/bin/env bash
# If the desktop tree changed, bump the RPM release and publish the lab repo.
# Watched paths do not include the spec or publish directory, so a publish
# cannot retrigger itself.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
stamp="$project_dir/publish/.auto-content-stamp"
spec="$project_dir/rpm/sentinel-desktop.spec"

err() { printf 'auto-publish: %s\n' "$*" >&2; }

content_digest() {
    (
        cd -- "$project_dir"
        find session scripts shell dashboard assets install.sh dot43pr \
            rpm/sentinel.repo \
            -type f ! -name '*.pyc' ! -path '*/__pycache__/*' \
            | LC_ALL=C sort | xargs -r sha256sum
    ) | sha256sum | awk '{print $1}'
}

bump_release() {
    python3 - "$spec" <<'PY'
import datetime
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
release = re.search(r"^Release:\s+(\d+)", text, re.M)
version = re.search(r"^Version:\s+(\S+)", text, re.M)
if not release or not version:
    raise SystemExit("auto-publish: cannot read Version/Release from spec")
number = int(release.group(1)) + 1
text = re.sub(r"^Release:\s+\d+", f"Release:        {number}", text, count=1, flags=re.M)
day = datetime.date.today().strftime("%a %b %d %Y")
entry = (
    f"* {day} Sentinel Packaging <packaging@sentinel.local> "
    f"- {version.group(1)}-{number}\n"
    "- Automatic lab publish of the current desktop tree.\n"
)
if "%changelog\n" not in text:
    raise SystemExit("auto-publish: spec has no %changelog")
text = text.replace("%changelog\n", "%changelog\n" + entry, 1)
path.write_text(text)
print(f"{version.group(1)}-{number}")
PY
}

case ${1:-} in
    --remember)
        mkdir -p -- "$project_dir/publish"
        content_digest > "$stamp"
        exit 0
        ;;
    --digest)
        content_digest
        exit 0
        ;;
    -h|--help)
        printf 'Usage: %s [--remember|--digest]\n' "${0##*/}"
        exit 0
        ;;
    "") ;;
    *) err "unknown argument: $1"; exit 2 ;;
esac

mkdir -p -- "$project_dir/publish"
now=$(content_digest)
old=
[[ -f $stamp ]] && old=$(cat -- "$stamp")
if [[ $now == "$old" ]]; then
    exit 0
fi
sleep 8
now2=$(content_digest)
if [[ $now2 != "$now" ]]; then
    exit 0
fi

ver=$(bump_release)
printf 'auto-publish: tree changed, publishing %s\n' "$ver"
"$project_dir/rpm/setup-lab-repo.sh"
content_digest > "$stamp"
printf 'auto-publish: %s is live at the lab repository\n' "$ver"
