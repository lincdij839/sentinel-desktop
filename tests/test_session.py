import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class SessionTests(unittest.TestCase):
    def test_material_symbols_font_is_shipped(self):
        font = ROOT / "assets" / "fonts" / "MaterialSymbolsOutlined.ttf"
        self.assertTrue(font.is_file())
        self.assertGreater(font.stat().st_size, 100_000)
        nerd = ROOT / "assets" / "fonts" / "JetBrainsMonoNerdFont-Regular.ttf"
        self.assertTrue(nerd.is_file())
        self.assertGreater(nerd.stat().st_size, 100_000)
        self.assertIn("JetBrainsMono Nerd Font", (ROOT / "dot43pr" / "quickshell" / "Theme.qml").read_text())
        self.assertIn("/usr/share/fonts/sentinel", (ROOT / "install.sh").read_text())
        self.assertIn("fc-cache", (ROOT / "install.sh").read_text())

    def test_wallpaper_asset_is_a_png(self):
        wallpaper = ROOT / "assets" / "wallpaper.png"
        self.assertTrue(wallpaper.is_file())
        self.assertEqual(wallpaper.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
        self.assertGreater(wallpaper.stat().st_size, 100_000)

    def test_shell_references_existing_files(self):
        shell = ROOT / "shell"
        for name in ("shell.qml", "Theme.qml", "Telemetry.qml", "Bar.qml", "Wallpaper.qml",
                     "HudOverlay.qml", "HudPanel.qml", "ArcReactor.qml", "Launcher.qml",
                     "Notifications.qml", "Lock.qml", "ShellState.qml", "Ime.qml",
                     "Network.qml", "Files.qml", "PowerMenu.qml", "PolkitDialog.qml",
                     "Audio.qml", "Bluetooth.qml", "Display.qml", "Osd.qml",
                     "pam/sentinel-lock"):
            self.assertTrue((shell / name).is_file(), name)
        self.assertIn("../assets/wallpaper.png", (shell / "Wallpaper.qml").read_text())
        self.assertTrue((ROOT / "scripts" / "telemetry.py").is_file())
        self.assertTrue((ROOT / "scripts" / "list-dir.py").is_file())

    def test_daily_driver_binds_and_ime(self):
        conf = (ROOT / "session" / "hyprland.lua").read_text()
        self.assertIn('home .. "/dot43pr/hypr"', conf)
        self.assertNotIn('home .. "/lian/hypr"', conf)
        self.assertIn("hyprland-hud.lua", conf)
        self.assertTrue((ROOT / "dot43pr" / "quickshell" / "shell.qml").is_file())
        self.assertTrue((ROOT / "dot43pr" / "hypr" / "keybinds.lua").is_file())
        rice = (ROOT / "dot43pr" / "hypr" / "hyprland.lua").read_text()
        self.assertIn("start-43pr-helpers.sh", rice)
        self.assertIn("start-qs.sh --path", rice)
        starter = (ROOT / "scripts" / "start-qs.sh").read_text()
        self.assertIn('$2 == "quickshell"', starter)
        self.assertNotIn("awk '/quickshell/", starter)
        self.assertIn("ipc|log|list|kill|msg", starter)
        self.assertIn("firefox", rice)
        binds = (ROOT / "dot43pr" / "hypr" / "keybinds.lua").read_text()
        self.assertIn("qs ipc call settings toggle", binds)
        self.assertIn("hyprquickpaper", binds)
        self.assertIn("qs ipc call powermenu toggle", binds)
        self.assertIn("43pr-bind.sh", binds)
        self.assertIn('+ S", hl.dsp.exec_cmd(bind .. " launcher")', binds)
        self.assertIn("SHIFT + S", binds)
        self.assertIn("ipc keybinds toggle", binds)
        self.assertIn('mode = "fullscreen"', binds)
        self.assertTrue((ROOT / "scripts" / "43pr-bind.sh").is_file())
        self.assertIn("force_default_wallpaper = 0", conf)
        self.assertIn("disable_splash_rendering = true", conf)
        self.assertIn('windowsIn', conf)
        self.assertIn('speed = 8', conf)
        self.assertIn("MOZ_ENABLE_WAYLAND", conf)
        self.assertIn("GDK_BACKEND", conf)
        self.assertIn("has_bin", rice)
        self.assertIn('hl.dsp.submap("")', conf)
        self.assertIn('hl.on("hyprland.start", leave_resize)', conf)
        self.assertNotIn("hl.plugin.load", conf)
        self.assertIn("firefox", rice)
        self.assertIn("ptyxis", rice)
        self.assertIn("toggle-ime.sh", conf)
        self.assertIn('hl.bind("CTRL + SPACE"', conf)
        self.assertTrue((ROOT / "scripts/toggle-ime.sh").is_file())
        self.assertTrue((ROOT / "session/hyprland-hud.lua").is_file())
        self.assertIn("start-qs.sh --path", (ROOT / "session/hyprland-hud.lua").read_text())
        self.assertIn("MOZ_ENABLE_WAYLAND", (ROOT / "session/hyprland-hud.lua").read_text())
        self.assertFalse((ROOT / "session" / "spatialoverview.lua").exists())
        pinyin = (ROOT / "session" / "fcitx5" / "conf" / "pinyin.conf").read_text()
        self.assertIn("FirstRun=False", pinyin)
        self.assertIn("CloudPinyinEnabled=False", pinyin)
        fcitx = (ROOT / "session" / "fcitx5" / "config").read_text()
        self.assertIn("TriggerKeys=Control+space", fcitx)
        self.assertNotIn("Super", fcitx)
        session = (ROOT / "session" / "sentinel-session").read_text()
        self.assertIn("QT_IM_MODULE=fcitx", session)
        self.assertIn("QT_IM_MODULES='wayland;fcitx;ibus'", session)
        self.assertIn("MOZ_ENABLE_WAYLAND", session)
        self.assertIn("GDK_BACKEND", session)
        self.assertNotIn("GTK_IM_MODULE=fcitx", session)
        self.assertIn("uwsm start", session)
        self.assertIn("start-hyprland", session)
        self.assertIn('start-hyprland -- --config', session)
        self.assertIn("hyprland.lua", session)
        self.assertIn('"$config_root/hyprland.lua"', session)
        self.assertIn("SENTINEL_SHELL", session)
        self.assertIn("setup-user.sh", session)
        self.assertIn("dot43pr/quickshell", session)
        self.assertNotIn("lian/qsl", session)
        self.assertIn("start-fcitx.sh", (ROOT / "scripts" / "start-43pr-helpers.sh").read_text())
        self.assertIn("session/fcitx5", (ROOT / "scripts" / "setup-user.sh").read_text())
        shell = (ROOT / "shell" / "shell.qml").read_text()
        self.assertIn("IdleMonitor", shell)
        self.assertNotIn("seconds * 1000", shell)

    def test_fcitx_setup_does_not_overwrite_existing_config(self):
        import tempfile
        script = ROOT / "session" / "start-fcitx.sh"
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config = home / ".config" / "fcitx5"
            config.mkdir(parents=True)
            marker = config / "config"
            marker.write_text("keep-me\n")
            env = {**os.environ, "HOME": str(home), "SENTINEL_HOME": str(ROOT), "PATH": "/usr/bin:/bin"}
            result = subprocess.run([str(script)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(marker.read_text(), "keep-me\n")
            self.assertTrue((config / "profile").is_file())

            fresh = Path(tmp) / "fresh"
            result = subprocess.run(
                [str(script)],
                env={**env, "HOME": str(fresh)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Control+space", (fresh / ".config" / "fcitx5" / "config").read_text())
            self.assertIn("FirstRun=False", (fresh / ".config" / "fcitx5" / "conf" / "pinyin.conf").read_text())
            seeded = Path(tmp) / "seeded"
            (seeded / ".config" / "fcitx5").mkdir(parents=True)
            (seeded / ".config" / "fcitx5" / "config").write_text("keep-me\n")
            result = subprocess.run(
                [str(script)],
                env={**env, "HOME": str(seeded)},
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((seeded / ".config" / "fcitx5" / "config").read_text(), "keep-me\n")
            self.assertIn("FirstRun=False", (seeded / ".config" / "fcitx5" / "conf" / "pinyin.conf").read_text())

    def test_setup_user_writes_app_env_and_skips_when_ready(self):
        import tempfile
        script = ROOT / "scripts" / "setup-user.sh"
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            home.mkdir()
            (home / ".config").mkdir()
            (home / ".config" / "quickshell").symlink_to(tmp)
            env = {**os.environ, "HOME": str(home), "SENTINEL_HOME": str(ROOT)}
            first = subprocess.run(
                [str(script), str(home), "tester"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            env_file = home / ".config" / "environment.d" / "50-sentinel-apps.conf"
            qs = home / ".local" / "bin" / "qs"
            self.assertTrue(env_file.is_file())
            self.assertIn("MOZ_ENABLE_WAYLAND=1", env_file.read_text())
            self.assertTrue(qs.is_symlink())
            self.assertEqual(qs.resolve(), (ROOT / "scripts" / "start-qs.sh").resolve())
            self.assertTrue((home / ".config" / "quickshell" / "shell.qml").is_symlink())
            self.assertTrue((home / "Pictures" / "Wallpapers").is_dir())
            self.assertTrue((home / "Pictures" / "Wallpapers" / "43pr").exists())
            self.assertTrue((home / ".config" / "43pr" / "bin" / "theme.py").exists())
            self.assertTrue((home / ".zshrc").is_symlink())
            self.assertTrue((home / ".cache" / "43pr").is_dir())
            self.assertTrue((home / ".local" / "state" / "43pr").is_dir())
            qs.unlink()
            second = subprocess.run(
                [str(script), str(home), "tester"],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertTrue(qs.is_symlink())

    def test_daily_driver_failure_paths_and_safe_power_mode(self):
        network = (ROOT / "shell" / "Network.qml").read_text()
        self.assertIn("onConnectionFailed", network)
        self.assertIn("CONNECTION TIMED OUT", network)

        power = (ROOT / "shell" / "PowerMenu.qml").read_text()
        self.assertIn("SENTINEL_POWER_DRY_RUN", power)
        self.assertIn("confirmTimeout", power)
        self.assertIn("onExited: (exitCode", power)
        self.assertIn("uwsm stop", power)
        self.assertIn("hl.dsp.exit()", power)

        files = (ROOT / "shell" / "Files.qml").read_text()
        self.assertIn("LIST FAILED", files)
        self.assertIn("OPEN", files)
        self.assertIn("file-ops.py", files)
        self.assertIn("DELETE", files)

        shell = (ROOT / "shell" / "shell.qml").read_text()
        self.assertIn("Math.max(5, raw)", shell)
        self.assertIn('dispatch", "dpms", "off"', shell)
        self.assertIn("wallpaper.py", shell)
        self.assertIn("SAVED", network)
        self.assertIn("nm-connections.py", network)

    def test_wallpaper_cycle_stores_choice(self):
        import tempfile
        script = ROOT / "scripts" / "wallpaper.py"
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            config = Path(tmp) / "config"
            library = Path(tmp) / "tree" / "assets" / "wallpapers"
            library.mkdir(parents=True)
            home.mkdir()
            (library / "a.png").write_bytes(b"\x89PNG\r\n\x1a\n")
            (library / "b.png").write_bytes(b"\x89PNG\r\n\x1a\n")
            env = {
                **os.environ,
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(config),
                "SENTINEL_HOME": str(Path(tmp) / "tree"),
            }
            first = subprocess.run([sys.executable, str(script), "next"], env=env, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertIn("b.png", first.stdout)
            second = subprocess.run([sys.executable, str(script), "next"], env=env, capture_output=True, text=True)
            self.assertIn("a.png", second.stdout)
            choice = (config / "sentinel" / "wallpaper").read_text().strip()
            self.assertTrue(choice.endswith("a.png"))

    @unittest.skipUnless(shutil.which("Hyprland"), "Hyprland is not installed")
    def test_hyprland_config_is_valid(self):
        command = ["Hyprland", "--verify-config", "--config", str(ROOT / "session" / "hyprland.lua")]
        if os.geteuid() == 0:
            command.append("--i-am-really-stupid")
        result = subprocess.run(
            command,
            env={**os.environ, "SENTINEL_HOME": str(ROOT)},
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertIn("config ok", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
