#!/usr/bin/env bash
# Build a GPG-signed DNF repository of Sentinel's own RPM.
#
#   rpm/build-repo.sh [--output DIR]
#
# Requires: rpm-build, createrepo_c, rpm-sign (rpmsign), gnupg2
# Signing key: $SENTINEL_GPG_HOME (default rpm/.gnupg). Created on first run
# and reused so package signatures stay verifiable.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
spec="$project_dir/rpm/sentinel-desktop.spec"
output="$project_dir/repo"
gpg_home="${SENTINEL_GPG_HOME:-$project_dir/rpm/.gnupg}"
gpg_name='Sentinel Desktop Packaging <packaging@sentinel.local>'
passphrase="${SENTINEL_GPG_PASSPHRASE-}"

err() { printf 'build-repo: %s\n' "$*" >&2; }

while (($#)); do
    case $1 in
        --output) output=${2:?--output needs a directory}; shift 2 ;;
        -h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) err "unknown argument: $1"; exit 2 ;;
    esac
done

for command in rpmbuild createrepo_c rpmsign gpg rpm rpmkeys; do
    command -v "$command" >/dev/null 2>&1 || {
        err "missing required command: $command"
        exit 1
    }
done
[[ -f $spec ]] || { err "spec not found: $spec"; exit 1; }

version=$(awk '/^Version:/{print $2; exit}' "$spec")
[[ -n $version ]] || { err "cannot read Version from $spec"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
top="$work/rpmbuild"
mkdir -p -- "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

name=sentinel-desktop
src_name="$name-$version"
src_root="$work/$src_name"
mkdir -p -- "$src_root"
for item in shell dashboard scripts assets session dot43pr image tests install.sh \
    README.md run-nested.sh run-demo.sh rpm; do
    [[ -e $project_dir/$item ]] || continue
    cp -a --no-preserve=context -- "$project_dir/$item" "$src_root/$item"
done
if [[ ! -f $project_dir/rpm/tls/ca.crt ]]; then
    "$project_dir/rpm/generate-tls.sh" "${SENTINEL_REPO_HOST_IP:-192.168.122.1}"
    mkdir -p -- "$src_root/rpm/tls"
    cp -a --no-preserve=context -- "$project_dir/rpm/tls/ca.crt" "$src_root/rpm/tls/ca.crt"
fi
find "$src_root" -name __pycache__ -type d -prune -exec rm -rf {} +
find "$src_root" -name .gnupg -type d -prune -exec rm -rf {} +
find "$src_root/rpm" -name '*.key' -delete
find "$src_root/rpm" -name '*.csr' -delete
repo_url=${SENTINEL_REPO_URL:-}
if [[ -z $repo_url && -f $project_dir/rpm/update.conf ]]; then
    repo_url=$(awk -F= '$1=="SENTINEL_REPO_URL"{sub(/^[^=]*=/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}' \
        "$project_dir/rpm/update.conf")
fi
# Never enable this repo for `dnf upgrade`. Desktop fixes go through
# sentinel-update only; Fedora system updates stay on Fedora repos.
repo_enabled=0
if [[ -z $repo_url ]]; then
    repo_url=file:///run/sentinel-update/sentinel-repo
fi
sed -e "s|__SENTINEL_REPO_URL__|$repo_url|" \
    -e "s|^enabled=.*|enabled=$repo_enabled|" \
    "$src_root/rpm/sentinel.repo" > "$src_root/rpm/sentinel.repo.new"
mv -f -- "$src_root/rpm/sentinel.repo.new" "$src_root/rpm/sentinel.repo"
if [[ -n ${SENTINEL_REPO_URL:-} ]]; then
    sed -i "s|^SENTINEL_REPO_URL=.*|SENTINEL_REPO_URL=$SENTINEL_REPO_URL|" \
        "$src_root/rpm/update.conf"
fi
tar -C "$work" -czf "$top/SOURCES/$src_name.tar.gz" "$src_name"

mkdir -p -- "$gpg_home"
chmod 700 -- "$gpg_home"
export GNUPGHOME="$gpg_home"
gpg_args=(--batch --pinentry-mode loopback --passphrase "$passphrase")
if ! gpg "${gpg_args[@]}" --list-secret-keys --with-colons | grep -q '^sec:'; then
    gpg "${gpg_args[@]}" --quick-generate-key "$gpg_name" rsa4096 sign never
fi
gpg "${gpg_args[@]}" --armor --export "$gpg_name" > "$top/SOURCES/RPM-GPG-KEY-sentinel"
[[ -s $top/SOURCES/RPM-GPG-KEY-sentinel ]] || { err "failed to export the signing key"; exit 1; }
fingerprint=$(gpg "${gpg_args[@]}" --list-secret-keys --with-colons -- "$gpg_name" \
    | awk -F: '/^fpr:/{print $10; exit}')
[[ -n $fingerprint ]] || { err "cannot read the signing key fingerprint"; exit 1; }

rpmbuild -bb \
    --define "_topdir $top" \
    --define "debug_package %{nil}" \
    "$spec"

shopt -s nullglob
rpms=("$top"/RPMS/*/*.rpm)
shopt -u nullglob
((${#rpms[@]})) || { err "rpmbuild produced no packages"; exit 1; }

# rpm 6 signs with OpenPGP; --load adds macros without replacing the system set.
macrofile="$work/rpmmacros"
cat > "$macrofile" <<EOF
%_gpg_name $gpg_name
%_gpg_path $gpg_home
%__gpg /usr/bin/gpg
%_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback --passphrase $passphrase
%_openpgp_sign gpg
%_openpgp_sign_id $fingerprint
EOF
rpmsign --load "$macrofile" --key-id "$fingerprint" --addsign "${rpms[@]}"
verify_root="$work/rpmroot"
mkdir -p -- "$verify_root"
rpmkeys --root "$verify_root" --import -- "$top/SOURCES/RPM-GPG-KEY-sentinel"
check=$(rpmkeys --root "$verify_root" --checksig -- "${rpms[@]}")
printf '%s\n' "$check"
printf '%s\n' "$check" | grep -qiE 'signatures OK|digest.*OK' \
    || { err "signed package failed rpmkeys --checksig"; exit 1; }

rm -rf -- "$output"
mkdir -p -- "$output"
cp -a -- "${rpms[@]}" "$output/"
cp -a -- "$top/SOURCES/RPM-GPG-KEY-sentinel" "$output/RPM-GPG-KEY-sentinel"
createrepo_c --pretty --compatibility "$output"
gpg "${gpg_args[@]}" --detach-sign --armor --local-user "$gpg_name" \
    --yes --output "$output/repodata/repomd.xml.asc" \
    "$output/repodata/repomd.xml"

printf 'Signed DNF repository at %s\n' "$output"
rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm\n' "${rpms[@]}"
