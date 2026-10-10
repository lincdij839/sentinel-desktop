import os
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
UPDATE = PROJECT / "session/sentinel-update"


class UpdateTests(unittest.TestCase):
    def test_rejects_a_path_that_is_not_a_source_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(
                ["bash", str(UPDATE), tmp],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Not a Sentinel source tree", result.stderr)

    def test_installs_from_an_explicit_source_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / "prefix"
            result = subprocess.run(
                [str(PROJECT / "install.sh"), "--prefix", str(prefix)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((prefix / "bin/sentinel-update").resolve().is_file())
            self.assertIn("mount -o ro", (prefix / "share/sentinel-desktop/session/sentinel-update").read_text())
        self.assertIn("find_mounted", UPDATE.read_text())
        self.assertIn("/dev/sr0", UPDATE.read_text())
        self.assertIn("/usr/src/sentinel-desktop", UPDATE.read_text())
        self.assertIn("--sync", UPDATE.read_text())
        self.assertIn("--full", UPDATE.read_text())
        self.assertIn("refresh_session", UPDATE.read_text())
        self.assertIn('install.sh" --prefix /usr --sync', UPDATE.read_text())
        self.assertIn("--repofrompath=sentinel-probe", UPDATE.read_text())
        self.assertIn("apply_https_rpm", UPDATE.read_text())
        self.assertIn("apply_local_rpm", UPDATE.read_text())
        self.assertIn("wait_for_pkg_lock", UPDATE.read_text())
        self.assertIn("--noproxy '*'", UPDATE.read_text())
        self.assertIn("repo_curl", UPDATE.read_text())
        self.assertIn("curl -kfsS", UPDATE.read_text())
        self.assertIn("enabled=0", (PROJECT / "rpm/sentinel.repo").read_text())
        self.assertIn("repo_enabled=0", (PROJECT / "rpm/build-repo.sh").read_text())
        self.assertNotIn("dnf.conf.d/50-sentinel.conf", (PROJECT / "rpm/sentinel-desktop.spec").read_text())
        self.assertIn("RPM-GPG-KEY-sentinel", UPDATE.read_text())
        self.assertIn("rpm --checksig", UPDATE.read_text())
        self.assertIn("apply_repo", UPDATE.read_text())
        self.assertIn("apply_dnf", UPDATE.read_text())
        self.assertIn("network_repo_url", UPDATE.read_text())
        self.assertIn("--offline-ok", UPDATE.read_text())
        self.assertIn("install.sh --prefix /usr --extras", UPDATE.read_text())
        self.assertTrue((PROJECT / "rpm/release.sh").is_file())
        self.assertTrue((PROJECT / "rpm/qemu-test-update.sh").is_file())
        self.assertTrue((PROJECT / "rpm/publish.sh").is_file())
        release = (PROJECT / "rpm/release.sh").read_text()
        self.assertIn("build-repo.sh", release)
        self.assertIn("qemu-test-update.sh", release)
        self.assertIn("publish.sh", release)
        timer = (PROJECT / "session/sentinel-update.timer").read_text()
        self.assertIn("OnBootSec=5min", timer)
        self.assertIn("OnUnitActiveSec=15min", timer)
        self.assertIn("WantedBy=timers.target", timer)
        self.assertTrue((PROJECT / "rpm/auto-publish.sh").is_file())
        self.assertTrue((PROJECT / "rpm/watch-and-publish.sh").is_file())
        self.assertTrue((PROJECT / "rpm/sentinel-auto-publish.service").is_file())
        auto = (PROJECT / "rpm/auto-publish.sh").read_text()
        self.assertIn("--remember", auto)
        self.assertIn("bump_release", auto)
        self.assertIn("setup-lab-repo.sh", auto)
        setup = (PROJECT / "rpm/setup-lab-repo.sh").read_text()
        self.assertIn("sentinel-auto-publish.service", setup)
        tls = (PROJECT / "rpm/generate-tls.sh").read_text()
        self.assertIn("TLS already valid", tls)
        installer = (PROJECT / "install.sh").read_text()
        self.assertIn("full_extras", installer)
        self.assertIn("install-43pr.sh", installer)
        self.assertNotIn("install-lianwall.sh", installer)
        self.assertNotIn("install-coucou.sh", installer)
        self.assertNotIn("install-phantomat.sh", installer)
        push = PROJECT / "scripts/push-update.sh"
        self.assertTrue(push.is_file())
        text = push.read_text()
        self.assertIn("install.sh --prefix /usr --sync", text)
        self.assertIn("sentinel-push", text)
        self.assertIn("SENTINEL_HOSTS", text)
        self.assertIn("hyprctl reload", text)
        self.assertIn("dismissnotify", text)
        bootstrap = PROJECT / "rpm/install-latest.sh"
        self.assertTrue(bootstrap.is_file())
        boot = bootstrap.read_text()
        self.assertIn("rpm -Uvh", boot)
        self.assertNotIn("--repofrompath=sentinel,", boot)
        self.assertIn("setup-user.sh", boot)
        self.assertIn("curl -kfsS", boot)
        self.assertIn("install-latest.sh", (PROJECT / "rpm/publish.sh").read_text())
