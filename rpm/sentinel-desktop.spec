Name:           sentinel-desktop
Version:        1.1.0
Release:        37%{?dist}
Summary:        Sentinel Wayland session, configuration, and tools

License:        MIT
Source0:        %{name}-%{version}.tar.gz
Source1:        RPM-GPG-KEY-sentinel
BuildArch:      noarch

Requires:       python3
Requires:       systemd
Requires(post): systemd
Requires(preun): systemd
Recommends:     hyprland
Recommends:     quickshell
Recommends:     hyprlock
Recommends:     hyprpolkitagent
Recommends:     rofi
Recommends:     swww
Recommends:     sddm
Recommends:     fontconfig
Recommends:     network-manager-applet
Recommends:     blueman
Recommends:     ImageMagick
Recommends:     papirus-icon-theme
Recommends:     adw-gtk3-theme
Recommends:     matugen
Recommends:     starship
Recommends:     kitty
Recommends:     brightnessctl
Recommends:     playerctl
Recommends:     cliphist

%description
Sentinel Desktop's own session files, the 43PR Hyprland + Quickshell rice,
scripts, fonts, and login theme. Hyprland and Quickshell come from their
COPR repositories. The HTTPS update repository is GPG-signed so clients
run: sudo sentinel-update.

%prep
%setup -q

%build

%install
install -d %{buildroot}%{_datadir}/sentinel-desktop
cp -a --no-preserve=context -- shell dashboard scripts assets session dot43pr \
    %{buildroot}%{_datadir}/sentinel-desktop/
find %{buildroot}%{_datadir}/sentinel-desktop -name __pycache__ -type d -prune -exec rm -rf {} +

install -d %{buildroot}%{_bindir}
ln -sfr %{buildroot}%{_datadir}/sentinel-desktop/session/sentinel-session \
    %{buildroot}%{_bindir}/sentinel-session
ln -sfr %{buildroot}%{_datadir}/sentinel-desktop/session/sentinel-ctl \
    %{buildroot}%{_bindir}/sentinel-ctl
# Real file so a later share-tree replace cannot delete the updater.
install -m 0755 session/sentinel-update %{buildroot}%{_bindir}/sentinel-update

install -d %{buildroot}%{_datadir}/wayland-sessions
sed 's|^Exec=.*|Exec=%{_bindir}/sentinel-session|' session/sentinel.desktop \
    > %{buildroot}%{_datadir}/wayland-sessions/sentinel.desktop

install -D -m 0644 session/sentinel-relabel.service \
    %{buildroot}/usr/lib/systemd/system/sentinel-relabel.service
install -D -m 0644 session/sentinel-update.service \
    %{buildroot}/usr/lib/systemd/system/sentinel-update.service
install -D -m 0644 session/sentinel-update.timer \
    %{buildroot}/usr/lib/systemd/system/sentinel-update.timer
install -D -m 0644 session/logind-lid.conf \
    %{buildroot}%{_prefix}/lib/systemd/logind.conf.d/50-sentinel.conf
install -D -m 0644 session/sddm/10-sentinel.conf \
    %{buildroot}%{_sysconfdir}/sddm.conf.d/10-sentinel.conf
install -d %{buildroot}%{_datadir}/sddm/themes
cp -a --no-preserve=context -- session/sddm/sentinel \
    %{buildroot}%{_datadir}/sddm/themes/sentinel

if [ -d assets/fonts ]; then
    install -d %{buildroot}%{_datadir}/fonts/sentinel
    cp -a --no-preserve=context -- assets/fonts/. \
        %{buildroot}%{_datadir}/fonts/sentinel/
fi

install -D -m 0644 %{SOURCE1} \
    %{buildroot}%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-sentinel
install -D -m 0644 rpm/sentinel.repo \
    %{buildroot}%{_sysconfdir}/yum.repos.d/sentinel.repo
install -D -m 0644 rpm/update.conf \
    %{buildroot}%{_sysconfdir}/sentinel/update.conf
if [ -f rpm/tls/ca.crt ]; then
    install -D -m 0644 rpm/tls/ca.crt \
        %{buildroot}%{_sysconfdir}/pki/ca-trust/source/anchors/sentinel-repo-ca.crt
fi

# Repair tree so --full extras still have sources without the disc.
install -d %{buildroot}/usr/src/sentinel-desktop
cp -a --no-preserve=context -- shell dashboard scripts assets session dot43pr \
    image tests install.sh README.md run-nested.sh run-demo.sh rpm \
    %{buildroot}/usr/src/sentinel-desktop/
find %{buildroot}/usr/src/sentinel-desktop -name __pycache__ -type d -prune -exec rm -rf {} +

%post
if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl enable sentinel-relabel.service >/dev/null 2>&1 || :
    /usr/bin/systemctl enable sentinel-update.timer >/dev/null 2>&1 || :
fi
if [ -x /usr/bin/fc-cache ] && [ -d %{_datadir}/fonts/sentinel ]; then
    /usr/bin/fc-cache -f -- %{_datadir}/fonts/sentinel >/dev/null 2>&1 || :
fi
if [ -x /usr/sbin/restorecon ]; then
    /usr/sbin/restorecon -RF -- \
        %{_datadir}/sentinel-desktop \
        %{_datadir}/sddm/themes/sentinel \
        %{_datadir}/fonts/sentinel \
        /usr/src/sentinel-desktop >/dev/null 2>&1 || :
fi
if [ -f %{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-sentinel ]; then
    /usr/bin/rpm --import %{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-sentinel >/dev/null 2>&1 || :
fi
if [ -f %{_sysconfdir}/yum.repos.d/sentinel.repo ]; then
    sed -i 's/^enabled=.*/enabled=0/' %{_sysconfdir}/yum.repos.d/sentinel.repo || :
fi
if [ -f %{_sysconfdir}/pki/ca-trust/source/anchors/sentinel-repo-ca.crt ] \
    && [ -x /usr/bin/update-ca-trust ]; then
    /usr/bin/update-ca-trust || :
fi

%preun
if [ "$1" -eq 0 ] && [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl disable --now sentinel-relabel.service >/dev/null 2>&1 || :
    /usr/bin/systemctl disable --now sentinel-update.timer >/dev/null 2>&1 || :
fi

%files
%{_datadir}/sentinel-desktop
%{_bindir}/sentinel-session
%{_bindir}/sentinel-ctl
%{_bindir}/sentinel-update
%{_datadir}/wayland-sessions/sentinel.desktop
/usr/lib/systemd/system/sentinel-relabel.service
/usr/lib/systemd/system/sentinel-update.service
/usr/lib/systemd/system/sentinel-update.timer
%{_prefix}/lib/systemd/logind.conf.d/50-sentinel.conf
%config(noreplace) %{_sysconfdir}/sddm.conf.d/10-sentinel.conf
%{_datadir}/sddm/themes/sentinel
%{_datadir}/fonts/sentinel
%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-sentinel
%config(noreplace) %{_sysconfdir}/yum.repos.d/sentinel.repo
%config(noreplace) %{_sysconfdir}/sentinel/update.conf
%{_sysconfdir}/pki/ca-trust/source/anchors/sentinel-repo-ca.crt
/usr/src/sentinel-desktop

%changelog
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-37
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-36
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-35
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-34
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-33
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-32
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-31
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-29
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-27
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-26
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-23
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-21
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-19
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-18
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-17
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-16
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-15
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-14
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-13
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-12
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-11
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-10
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-9
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-8
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-7
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-6
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-5
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-4
- Automatic lab publish of the current desktop tree.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-3
- Faster application launch, leave the resize submap on login, and stop
  sentinel-update from registering the sentinel DNF repo twice.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-2
- Trust the lab HTTPS repository CA without a file:// sslcacert URL.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.1.0-1
- HTTPS update repository, daily timer, and release pipeline.
* Sat Oct 10 2026 Sentinel Packaging <packaging@sentinel.local> - 1.0.0-1
- Initial RPM of Sentinel configuration and tools.
