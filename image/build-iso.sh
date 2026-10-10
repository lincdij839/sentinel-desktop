#!/usr/bin/env bash
# Build the Sentinel Desktop installer ISO from a Fedora Everything netinstall ISO.
#
#   image/build-iso.sh --input Fedora-Everything-netinst.iso --output sentinel.iso [--kickstart FILE] [--with-repo]
#
# The input ISO is never modified. The output carries the Kickstart (/sentinel.ks),
# the project payload (/sentinel-desktop), a signed DNF repository (/sentinel-repo)
# when rpm-build tools are present, and boot entries that start the installer with it.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
input=
output=
kickstart="$project_dir/image/sentinel.ks"
with_repo=0
payload=(shell dashboard scripts assets session dot43pr image tests install.sh README.md run-nested.sh run-demo.sh rpm)

err() { printf 'build-iso: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --input) input=${2:?--input needs a file}; shift 2 ;;
        --output) output=${2:?--output needs a file}; shift 2 ;;
        --kickstart) kickstart=${2:?--kickstart needs a file}; shift 2 ;;
        --with-repo) with_repo=1; shift ;;
        -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

[[ -f $input ]] || { err "--input must be an existing ISO."; exit 2; }
[[ -n $output ]] || { err "--output is required."; exit 2; }
[[ $input != "$output" ]] || { err "--output must differ from --input."; exit 2; }
[[ -f $kickstart ]] || { err "kickstart not found: $kickstart"; exit 2; }
for command in xorriso implantisomd5; do
    command -v "$command" >/dev/null 2>&1 || { err "missing required command: $command"; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

label="$(xorriso -indev "$input" -report_system_area plain 2>&1 | sed -n "s/^Volume id *: '\(.*\)'/\1/p")"
[[ -n $label ]] || { err "cannot read the volume label of $input"; exit 1; }

mkdir -p "$work/payload/sentinel-desktop"
for item in "${payload[@]}"; do
    cp -a --no-preserve=context -- "$project_dir/$item" "$work/payload/sentinel-desktop/$item"
done
find "$work/payload" -name __pycache__ -type d -prune -exec rm -rf {} +

patch_grub() {
    local iso_path=$1 name=$2
    xorriso -osirrox on -indev "$input" -extract "$iso_path" "$work/$name" >/dev/null 2>&1 ||
        { err "$iso_path is missing from $input"; exit 1; }
    chmod u+w "$work/$name"
    sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=hd:LABEL=$label:/sentinel.ks inst.repo=https://mirrors.ustc.edu.cn/fedora/releases/44/Everything/x86_64/os/|" "$work/$name"
    grep -q 'inst.ks=' "$work/$name" || { err "no inst.stage2 entry found in $iso_path"; exit 1; }
    sed -i "s|^set timeout=.*|set timeout=10|; s|Install Fedora [0-9]*|Install Sentinel Desktop|" "$work/$name"
}
patch_grub /EFI/BOOT/grub.cfg grub-efi.cfg
patch_grub /boot/grub2/grub.cfg grub-bios.cfg

cp -- "$kickstart" "$work/sentinel.ks"
xorriso_maps=(
    -map "$work/sentinel.ks" /sentinel.ks
    -map "$work/payload/sentinel-desktop" /sentinel-desktop
    -map "$work/grub-efi.cfg" /EFI/BOOT/grub.cfg
    -map "$work/grub-bios.cfg" /boot/grub2/grub.cfg
)
repo_dir=
if ((with_repo)); then
    "$project_dir/rpm/build-repo.sh" --output "$work/payload/sentinel-repo"
    repo_dir="$work/payload/sentinel-repo"
elif [[ -d $project_dir/repo/repodata ]]; then
    repo_dir="$project_dir/repo"
fi
if [[ -n $repo_dir ]]; then
    xorriso_maps+=(-map "$repo_dir" /sentinel-repo)
fi
rm -f -- "$output"
xorriso -indev "$input" -outdev "$output" -boot_image any replay \
    "${xorriso_maps[@]}" \
    -commit >/dev/null 2>&1 || { err "xorriso failed"; rm -f -- "$output"; exit 1; }

implantisomd5 "$output" >/dev/null
printf 'Built %s (label %s)\n' "$output" "$label"
