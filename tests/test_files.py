import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIST = ROOT / "scripts" / "list-dir.py"


class ListDirTests(unittest.TestCase):
    def run_list(self, path: str, *args: str) -> dict:
        result = subprocess.run(["python3", str(LIST), path, *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_lists_visible_entries_and_hides_dotfiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Notes").mkdir()
            (root / "readme.txt").write_text("ok")
            (root / ".secret").write_text("hidden")
            visible = self.run_list(tmp)
            self.assertEqual(visible["error"], "")
            self.assertEqual([item["name"] for item in visible["entries"]], ["Notes", "readme.txt"])
            self.assertTrue(visible["entries"][0]["dir"])
            self.assertEqual(visible["entries"][0]["kind"], "DIR")
            self.assertEqual(visible["entries"][1]["kind"], "FILE")
            hidden = self.run_list(tmp, "--hidden")
            self.assertIn(".secret", [item["name"] for item in hidden["entries"]])

    def test_reports_symbolic_links(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "target").write_text("ok")
            (root / "link").symlink_to("target")
            entries = {item["name"]: item for item in self.run_list(tmp)["entries"]}
            self.assertEqual(entries["link"]["kind"], "LINK")

    def test_missing_directory_is_reported(self):
        missing = self.run_list("/tmp/sentinel-missing-dir-does-not-exist")
        self.assertEqual(missing["entries"], [])
        self.assertNotEqual(missing["error"], "")

    def test_script_does_not_create_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            before = set(os.listdir(tmp))
            self.run_list(tmp)
            self.assertEqual(set(os.listdir(tmp)), before)


class FileOpsTests(unittest.TestCase):
    def run_op(self, *args: str) -> dict:
        script = ROOT / "scripts" / "file-ops.py"
        result = subprocess.run(["python3", str(script), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_copy_move_and_delete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "box"
            source.mkdir()
            (source / "note.txt").write_text("hello")
            copied = self.run_op("copy", str(source / "note.txt"), str(root))
            self.assertEqual(copied["error"], "")
            self.assertTrue((root / "note.txt").is_file())
            other = root / "other"
            other.mkdir()
            moved = self.run_op("move", str(root / "note.txt"), str(other))
            self.assertEqual(moved["error"], "")
            self.assertFalse((root / "note.txt").exists())
            self.assertEqual((other / "note.txt").read_text(), "hello")
            removed = self.run_op("delete", str(other / "note.txt"))
            self.assertEqual(removed["error"], "")
            self.assertFalse((other / "note.txt").exists())

    def test_refuses_home_and_existing_destination(self):
        home = self.run_op("delete", str(Path.home()))
        self.assertEqual(home["error"], "REFUSED HOME")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "note.txt").write_text("a")
            (root / "dest").mkdir()
            (root / "dest" / "note.txt").write_text("b")
            copied = self.run_op("copy", str(root / "note.txt"), str(root / "dest"))
            self.assertEqual(copied["error"], "EXISTS")

    def test_places_include_home(self):
        payload = self.run_op("places")
        self.assertEqual(payload["error"], "")
        self.assertEqual(payload["places"][0]["name"], "HOME")
        self.assertEqual(payload["places"][0]["path"], str(Path.home()))


class MonitorConfigTests(unittest.TestCase):
    def test_round_trip_rejects_bad_scale(self):
        script = ROOT / "scripts" / "monitors.py"
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "XDG_CONFIG_HOME": tmp, "HOME": tmp}
            denied = subprocess.run(["python3", str(script), "set", "DP-1", "9"],
                                    capture_output=True, text=True, env=env)
            self.assertEqual(json.loads(denied.stdout)["error"], "REFUSED")
            saved = subprocess.run(["python3", str(script), "set", "DP-1", "1.5"],
                                   capture_output=True, text=True, env=env)
            self.assertEqual(json.loads(saved.stdout)["scales"]["DP-1"], 1.5)
            text = (Path(tmp) / "sentinel" / "monitors.conf").read_text()
            self.assertEqual(text.strip(), "DP-1 1.5")


class NetworkConnectionParseTests(unittest.TestCase):
    def test_parses_saved_vpn_and_escaped_colons(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("nm_connections", ROOT / "scripts" / "nm-connections.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        saved = "Office\\:VPN:vpn\nWired:802-3-ethernet\nCafe:802-11-wireless\n"
        active = "Wired\n"
        items = {item["name"]: item for item in module.parse_connections(saved, active)}
        self.assertTrue(items["Office:VPN"]["vpn"])
        self.assertFalse(items["Office:VPN"]["active"])
        self.assertTrue(items["Wired"]["active"])
        self.assertEqual(items["Cafe"]["type"], "802-11-wireless")


class ScreenshotScriptTests(unittest.TestCase):
    def test_saves_region_and_reports_cancel(self):
        script = ROOT / "scripts" / "screenshot.sh"
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp) / "bin"
            bindir.mkdir()
            home = Path(tmp) / "home"
            home.mkdir()
            (bindir / "slurp").write_text("#!/bin/sh\nprintf '0,0 2x2'\n")
            (bindir / "grim").write_text("#!/bin/sh\nlast=\nwhile [ $# -gt 0 ]; do last=$1; shift; done\nprintf 'png' > \"$last\"\n")
            (bindir / "wl-copy").write_text("#!/bin/sh\ncat >/dev/null\n")
            (bindir / "gdbus").write_text("#!/bin/sh\nexit 0\n")
            for name in ("slurp", "grim", "wl-copy", "gdbus"):
                (bindir / name).chmod(0o755)
            env = {**os.environ, "PATH": f"{bindir}:/usr/bin:/bin", "HOME": str(home)}
            saved = subprocess.run([str(script)], capture_output=True, text=True, env=env)
            self.assertEqual(saved.returncode, 0, saved.stderr)
            shots = list((home / "Pictures" / "Screenshots").glob("sentinel-*.png"))
            self.assertEqual(len(shots), 1)
            (bindir / "slurp").write_text("#!/bin/sh\nexit 1\n")
            cancelled = subprocess.run([str(script)], capture_output=True, text=True, env=env)
            self.assertEqual(cancelled.returncode, 0, cancelled.stderr)
            self.assertEqual(len(list((home / "Pictures" / "Screenshots").glob("sentinel-*.png"))), 1)


if __name__ == "__main__":
    unittest.main()
