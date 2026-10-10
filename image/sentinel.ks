# Sentinel Desktop installer Kickstart.
# Used with the Fedora Everything netinstall ISO (see image/build-iso.sh): packages come
# from the network repositories, the Sentinel payload comes from the installer media.
# Language, keyboard, timezone, disk and user are left for the installer to ask.

# A direct mirror. The Fedora metalink host times out on some networks, and Anaconda
# then spends minutes probing mirrors while it sets up the installation source.
url --url="https://mirrors.ustc.edu.cn/fedora/releases/44/Everything/x86_64/os/"
repo --name=sentinel-updates --baseurl="https://mirrors.ustc.edu.cn/fedora/updates/44/Everything/x86_64/"
# Hyprland and Quickshell are not in the Fedora repositories; they come from these COPR repos.
repo --name=copr-hyprland --baseurl="https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-44-x86_64/"
repo --name=copr-quickshell --baseurl="https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/fedora-44-x86_64/"

firstboot --disable
services --enabled=sddm,NetworkManager,bluetooth,sshd,qemu-guest-agent
network --bootproto=dhcp --activate

%packages
@core
@hardware-support
@fonts
sddm
sddm-wayland-generic
qt6-qtquickcontrols2
hyprland
uwsm
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
quickshell
qt6-qtwayland
qt6-qtdeclarative
ptyxis
kitty
rofi
hyprlock
hyprpolkitagent
network-manager-applet
blueman
ImageMagick
papirus-icon-theme
adw-gtk3-theme
gnome-themes-extra
jq
gammastep
cava
eza
google-roboto-mono-fonts
jetbrains-mono-fonts-all
qt6-qt5compat
swww
matugen
starship
tar
unzip
libnotify
python3
grim
slurp
swappy
wl-clipboard
cliphist
brightnessctl
playerctl
pamixer
pavucontrol
pipewire
pipewire-alsa
pipewire-pulseaudio
pipewire-utils
wireplumber
power-profiles-daemon
upower
NetworkManager
NetworkManager-wifi
dbus-daemon
fcitx5
fcitx5-chinese-addons
fcitx5-gtk
fcitx5-qt
fcitx5-qt6
fcitx5-configtool
Thunar
thunar-volman
thunar-archive-plugin
tumbler
ffmpegthumbnailer
xarchiver
gvfs
gvfs-mtp
xdg-utils
xdg-user-dirs
polkit
openssh-server
qemu-guest-agent
firefox
loupe
mpv
btop
fastfetch
fzf
git
qt6ct
qt6-qtsvg
bluez
bluez-tools
mesa-dri-drivers
google-noto-sans-mono-vf-fonts
google-noto-sans-cjk-fonts
google-noto-color-emoji-fonts
jetbrains-mono-fonts
fira-code-fonts
gtk-layer-shell
webkit2gtk4.1
libappindicator-gtk3
libsecret
gnome-keyring
git
gcc-c++
make
pkgconf-pkg-config
hyprland-devel
hyprgraphics-devel
pango-devel
lua-devel
libdrm-devel
libinput-devel
systemd-devel
wayland-devel
libxkbcommon-devel
pixman-devel
%end

%post --nochroot --erroronfail --log=/mnt/sysimage/root/sentinel-copy.log
set -eu

source_dir=/run/install/repo/sentinel-desktop
if [ ! -d "$source_dir" ]; then
	echo "Sentinel payload is missing from the installer media: $source_dir" >&2
	exit 1
fi

rm -rf /mnt/sysimage/usr/src/sentinel-desktop
mkdir -p /mnt/sysimage/usr/src
cp -a "$source_dir" /mnt/sysimage/usr/src/sentinel-desktop
chmod -R a+rX /mnt/sysimage/usr/src/sentinel-desktop

repo_dir=/run/install/repo/sentinel-repo
if [ -d "$repo_dir/repodata" ]; then
	rm -rf /mnt/sysimage/usr/src/sentinel-desktop/repo
	cp -a "$repo_dir" /mnt/sysimage/usr/src/sentinel-desktop/repo
	chmod -R a+rX /mnt/sysimage/usr/src/sentinel-desktop/repo
fi
%end

%post --erroronfail --log=/root/sentinel-install.log
set -eu

repo=/usr/src/sentinel-desktop/repo
if [ -d "$repo/repodata" ] && ls "$repo"/*.rpm >/dev/null 2>&1; then
	if [ -f "$repo/RPM-GPG-KEY-sentinel" ]; then
		rpm --import "$repo/RPM-GPG-KEY-sentinel"
	fi
	rpm --checksig "$repo"/*.rpm
	rpm -Uvh "$repo"/*.rpm
	/usr/src/sentinel-desktop/install.sh --prefix /usr --extras
else
	/usr/src/sentinel-desktop/install.sh --prefix /usr --extras
fi
test -f /usr/src/sentinel-desktop/install.sh
test -x /usr/bin/sentinel-update

systemctl set-default graphical.target

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
	for home in /home/*; do
		if [ -d "$home" ]; then
			user=$(stat -c %U "$home")
			runuser -u "$user" -- xdg-user-dirs-update || true
			# install -d can leave Pictures owned by root; the session user
			# then cannot add wallpapers.
			chown -R "$user:$user" "$home" || true
		fi
	done
fi

# Preselect the Sentinel session on the SDDM login screen.
install -d -o sddm -g sddm /var/lib/sddm
printf '[Last]\nSession=/usr/share/wayland-sessions/sentinel.desktop\n' > /var/lib/sddm/state.conf
chown sddm:sddm /var/lib/sddm/state.conf

# Prefer the Sentinel greeter theme (username + password fields).
test -f /etc/sddm.conf.d/10-sentinel.conf
test -f /usr/share/sddm/themes/sentinel/Main.qml
%end
