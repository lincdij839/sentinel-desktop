import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
INSTALL = PROJECT / "install.sh"
BUILD = PROJECT / "image/build-iso.sh"
KICKSTART = PROJECT / "image/sentinel.ks"

GRUB = """set timeout=60
menuentry 'Install Fedora 44' {
\tlinux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=TEST-LABEL quiet
}
"""


class InstallTests(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.prefix = Path(self._dir.name)

    def run_install(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([str(INSTALL), "--prefix", str(self.prefix), *args],
                              capture_output=True, text=True)

    def test_installs_session_and_payload(self) -> None:
        self.assertEqual(self.run_install().returncode, 0)
        share = self.prefix / "share/sentinel-desktop"
        for name in ("shell/shell.qml", "dashboard/Dashboard.qml", "scripts/telemetry.py",
                     "assets/wallpaper.png", "session/hyprland.lua",
                     "session/sentinel-update", "session/sentinel-relabel",
                     "dot43pr/quickshell/shell.qml", "dot43pr/hypr/hyprland.lua"):
            self.assertTrue((share / name).is_file(), name)
        entry = (self.prefix / "share/wayland-sessions/sentinel.desktop").read_text()
        self.assertIn(f"Exec={self.prefix}/bin/sentinel-session", entry)
        self.assertTrue((self.prefix / "bin/sentinel-session").resolve().is_file())
        self.assertTrue((self.prefix / "bin/sentinel-update").resolve().is_file())
        self.assertTrue((share / "shell/dashboard/Dashboard.qml").is_file())
        installer = INSTALL.read_text()
        self.assertIn("copy_file", installer)
        self.assertIn("mv -f --", installer)
        self.assertIn("${dest}.new", installer)
        self.assertNotIn("$share_dir/$item.new", installer)
        marker = share / "session/hyprland.lua"
        first = marker.stat().st_mtime_ns
        self.assertEqual(self.run_install().returncode, 0)
        self.assertTrue(marker.is_file())
        self.assertGreaterEqual(marker.stat().st_mtime_ns, first)

    def test_sync_installs_payload_without_optional_hooks(self) -> None:
        installer = INSTALL.read_text()
        self.assertIn("sync_only", installer)
        self.assertIn('((sync_only == 0))', installer)
        self.assertEqual(self.run_install("--sync").returncode, 0)
        share = self.prefix / "share/sentinel-desktop"
        self.assertTrue((share / "session/hyprland.lua").is_file())
        self.assertTrue((share / "scripts/toggle-ime.sh").is_file())

    def test_dry_run_changes_nothing(self) -> None:
        result = self.run_install("--dry-run")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(list(self.prefix.iterdir()), [])

    def test_uninstall_removes_everything(self) -> None:
        self.run_install()
        self.assertEqual(self.run_install("--uninstall").returncode, 0)
        self.assertFalse((self.prefix / "share/sentinel-desktop").exists())
        self.assertFalse((self.prefix / "share/wayland-sessions/sentinel.desktop").exists())
        self.assertFalse((self.prefix / "bin/sentinel-session").is_symlink())


class KickstartTests(unittest.TestCase):
    def test_kickstart_installs_the_session(self) -> None:
        text = KICKSTART.read_text()
        for needle in ("sddm", "hyprland", "quickshell", "install.sh --prefix /usr",
                       "sentinel.desktop", "/run/install/repo/sentinel-desktop",
                       "/usr/src/sentinel-desktop",
                       "sdegler/hyprland", "errornointernet/quickshell",
                       "Session=/usr/share/wayland-sessions/sentinel.desktop",
                       "uwsm", "fcitx5", "fcitx5-chinese-addons",
                       "fcitx5-qt6", "Thunar", "gvfs", "polkit",
                       "firefox", "bluez", "bluetooth",
                       "cliphist", "swappy", "playerctl", "xdg-user-dirs",
                       "tumbler", "jetbrains-mono-fonts",
                       "qt6-qtquickcontrols2", "10-sentinel.conf",
                       "openssh-server", "qemu-guest-agent",
                       "sshd,qemu-guest-agent",
                       "gtk-layer-shell", "webkit2gtk4.1", "libappindicator-gtk3",
                       "hyprland-devel", "gcc-c++",
                       "kitty", "rofi", "hyprlock", "hyprpolkitagent",
                       "matugen", "starship",
                       "network-manager-applet", "blueman", "ImageMagick",
                       "papirus-icon-theme", "jq",
                       "qt6-qt5compat", "swww", "tar",
                       "mirrors.ustc.edu.cn/fedora/releases/44/Everything/x86_64/os/",
                       "mirrors.ustc.edu.cn/fedora/updates/44/Everything/x86_64/",
                       "/run/install/repo/sentinel-repo",
                       "RPM-GPG-KEY-sentinel",
                       "rpm --import",
                       "rpm --checksig",
                       "rpm -Uvh",
                       "install.sh --prefix /usr --extras"):
            self.assertIn(needle, text)
        self.assertNotIn("url --metalink", text)
        self.assertNotIn("repo --name=sentinel-updates --metalink", text)
        self.assertNotIn("rm -rf /root/sentinel-src", text)
        self.assertNotIn("dwm", text)
        builder = BUILD.read_text()
        self.assertIn("--with-repo", builder)
        self.assertIn("/sentinel-repo", builder)
        installer = (PROJECT / "install.sh").read_text()
        self.assertIn("/usr/src/sentinel-desktop", installer)
        self.assertIn("source_items=", installer)
        self.assertIn("--sync", installer)
        self.assertIn("sync_only", installer)
        self.assertIn("--extras", installer)
        self.assertIn("install_extras", installer)
        self.assertIn(" rpm", installer)

    def test_sddm_theme_has_login_fields(self) -> None:
        theme = PROJECT / "session/sddm/sentinel/Main.qml"
        text = theme.read_text()
        self.assertIn("TextField", text)
        self.assertIn("password", text)
        self.assertIn("sddm.login", text)
        self.assertIn("import QtQuick.Controls as QQC", text)
        self.assertIn("QQC.ComboBox", text)
        self.assertIn("QQC.TextField", text)
        self.assertNotIn("SddmComponents", text)
        installer = (PROJECT / "install.sh").read_text()
        self.assertIn("--no-preserve=context", installer)
        self.assertIn("restorecon -RF", installer)
        self.assertIn("sentinel-relabel.service", installer)
        self.assertIn("/usr/share/sddm/themes/*", installer)
        self.assertNotIn("install-phantomat.sh", installer)
        self.assertTrue((PROJECT / "scripts/install-43pr.sh").is_file())
        self.assertIn('"$scripts/install-43pr.sh"', installer)
        self.assertNotIn("install-lianwall.sh", installer)
        pr = (PROJECT / "scripts/install-43pr.sh").read_text()
        self.assertIn("rofi", pr)
        self.assertIn("hyprlock", pr)
        self.assertIn("network-manager-applet", pr)
        self.assertIn("--skip-unavailable", pr)
        self.assertIn("matugen", pr)
        self.assertIn("starship", pr)
        self.assertIn("43PR/dotfiles", pr)
        self.assertIn("Before=display-manager.service", (PROJECT / "session/sentinel-relabel.service").read_text())
        self.assertTrue((PROJECT / "session/sddm/10-sentinel.conf").is_file())
        self.assertIn("Current=sentinel",
                      (PROJECT / "session/sddm/10-sentinel.conf").read_text())
        self.assertIn("GreeterEnvironment",
                      (PROJECT / "session/sddm/10-sentinel.conf").read_text())
        self.assertIn("hyprland-uwsm.desktop", installer)
        self.assertIn("sentinel.desktop", installer)
        self.assertFalse((PROJECT / "scripts/install-lianwall.sh").exists())
        self.assertFalse((PROJECT / "scripts/start-lianwall.sh").exists())
        self.assertFalse((PROJECT / "scripts/install-coucou.sh").exists())
        self.assertFalse((PROJECT / "scripts/start-coucou.sh").exists())
        self.assertFalse((PROJECT / "scripts/install-phantomat.sh").exists())
        setup = (PROJECT / "scripts/setup-user.sh").read_text()
        self.assertIn("Pictures/Wallpapers", setup)
        self.assertIn('rm -f -- "$home/.lian"', setup)
        self.assertIn(".config/lianwall", setup)
        self.assertIn("Pictures/Wallpapers/43pr", setup)
        self.assertIn("theme.py", setup)
        self.assertIn("dot43pr", setup)
        self.assertIn("quickshell/Theme.qml", setup)
        self.assertIn("session/fcitx5", setup)
        self.assertIn("already_ready", setup)
        self.assertIn("owned_by_root", setup)
        self.assertIn("repair_home_tree", setup)
        self.assertIn("50-sentinel-apps.conf", setup)
        self.assertIn("start-qs.sh", setup)
        helpers = (PROJECT / "scripts/start-43pr-helpers.sh").read_text()
        self.assertIn("start-43pr-wallpaper.sh", helpers)
        self.assertIn("hyprpolkitagent", helpers)
        self.assertIn("blueman-applet", helpers)
        self.assertIn("cliphist store", helpers)
        wallpaper = (PROJECT / "scripts/start-43pr-wallpaper.sh").read_text()
        self.assertIn("awww", wallpaper)
        self.assertIn("swww img", wallpaper)
        self.assertIn("wallpapers/43pr", wallpaper)
        self.assertTrue((PROJECT / "assets/wallpapers/43pr").is_dir())
        self.assertGreater(len(list((PROJECT / "assets/wallpapers/43pr").glob("wallhaven-*"))), 2)
        self.assertTrue((PROJECT / "dot43pr/.zshrc").is_file())
        kitty_conf = (PROJECT / "dot43pr/kitty/kitty.conf").read_text()
        self.assertIn("JetBrainsMono Nerd Font", kitty_conf)
        self.assertIn("Noto Sans CJK SC", kitty_conf)
        self.assertIn("symbol_map", kitty_conf)
        self.assertTrue((PROJECT / "scripts/start-qs.sh").is_file())
        self.assertIn("FirstRun=False", (PROJECT / "session/fcitx5/conf/pinyin.conf").read_text())
        self.assertTrue((PROJECT / "session/sddm/sentinel/background.png").is_file())
        self.assertTrue((PROJECT / "assets/wallpaper.png").is_file())


@unittest.skipUnless(shutil.which("xorriso") and shutil.which("implantisomd5"),
                     "xorriso/implantisomd5 are not installed")
class IsoBuildTests(unittest.TestCase):
    def test_output_iso_carries_kickstart_payload_and_boot_args(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            tree = root / "tree"
            for rel in ("EFI/BOOT/grub.cfg", "boot/grub2/grub.cfg"):
                (tree / rel).parent.mkdir(parents=True, exist_ok=True)
                (tree / rel).write_text(GRUB)
            source = root / "in.iso"
            subprocess.run(["xorriso", "-as", "mkisofs", "-V", "TEST-LABEL", "-o", str(source), str(tree)],
                           check=True, capture_output=True)

            output = root / "out.iso"
            result = subprocess.run([str(BUILD), "--input", str(source), "--output", str(output)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

            extract = root / "extract"
            extract.mkdir()
            subprocess.run(["xorriso", "-osirrox", "on", "-indev", str(output),
                            "-extract", "/", str(extract)], check=True, capture_output=True)
            self.assertTrue((extract / "sentinel.ks").is_file())
            self.assertTrue((extract / "sentinel-desktop/install.sh").is_file())
            self.assertTrue((extract / "sentinel-desktop/shell/shell.qml").is_file())
            self.assertTrue((extract / "sentinel-desktop/session/hyprland.lua").is_file())
            self.assertTrue((extract / "sentinel-desktop/dot43pr/quickshell/shell.qml").is_file())
            self.assertTrue((extract / "sentinel-desktop/tests").is_dir())
            self.assertTrue((extract / "sentinel-desktop/image/sentinel.ks").is_file())
            self.assertTrue((extract / "sentinel-desktop/README.md").is_file())
            self.assertTrue((extract / "sentinel-desktop/rpm/sentinel-desktop.spec").is_file())
            self.assertTrue((extract / "sentinel-desktop/rpm/build-repo.sh").is_file())
            self.assertFalse((extract / "sentinel-desktop/.git").exists())
            for rel in ("EFI/BOOT/grub.cfg", "boot/grub2/grub.cfg"):
                cfg = (extract / rel).read_text()
                self.assertIn("inst.stage2=hd:LABEL=TEST-LABEL inst.ks=hd:LABEL=TEST-LABEL:/sentinel.ks", cfg)
            self.assertTrue(source.exists())

    def test_rejects_same_input_and_output(self) -> None:
        result = subprocess.run([str(BUILD), "--input", str(BUILD), "--output", str(BUILD)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
