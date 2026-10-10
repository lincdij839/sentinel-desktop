import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
SPEC = PROJECT / "rpm/sentinel-desktop.spec"
BUILD_REPO = PROJECT / "rpm/build-repo.sh"
REPO_FILE = PROJECT / "rpm/sentinel.repo"


class PackagingLayoutTests(unittest.TestCase):
    def test_spec_packages_sentinel_config_and_tools(self) -> None:
        text = SPEC.read_text()
        for needle in (
            "Name:           sentinel-desktop",
            "BuildArch:      noarch",
            "Source1:        RPM-GPG-KEY-sentinel",
            "%{_datadir}/sentinel-desktop",
            "%{_bindir}/sentinel-session",
            "%{_bindir}/sentinel-ctl",
            "%{_bindir}/sentinel-update",
            "/usr/lib/systemd/system/sentinel-relabel.service",
            "/usr/src/sentinel-desktop",
            "%{_datadir}/fonts/sentinel",
            "%{_sysconfdir}/pki/rpm-gpg/RPM-GPG-KEY-sentinel",
            "%{_sysconfdir}/yum.repos.d/sentinel.repo",
            "%{_sysconfdir}/sentinel/update.conf",
            "sentinel-repo-ca.crt",
            "sentinel-update.timer",
            "session/sddm/sentinel",
            "rpm --import",
        ):
            self.assertIn(needle, text)

    def test_repo_file_requires_gpg(self) -> None:
        text = REPO_FILE.read_text()
        self.assertIn("[sentinel]", text)
        self.assertIn("gpgcheck=1", text)
        self.assertIn("repo_gpgcheck=1", text)
        self.assertIn("RPM-GPG-KEY-sentinel", text)
        self.assertIn("__SENTINEL_REPO_URL__", text)
        self.assertIn("enabled=0", text)
        self.assertIn("skip_if_unavailable=1", text)
        self.assertIn("timeout=8", text)
        self.assertIn("sslcacert", text)

    def test_build_repo_signs_and_runs_createrepo(self) -> None:
        self.assertTrue(BUILD_REPO.is_file())
        text = BUILD_REPO.read_text()
        for needle in (
            "rpmbuild",
            "createrepo_c",
            "rpmsign",
            "--addsign",
            "_openpgp_sign_id",
            "--key-id",
            "RPM-GPG-KEY-sentinel",
            "repomd.xml.asc",
            "--quick-generate-key",
            "GNUPGHOME",
        ):
            self.assertIn(needle, text)
        self.assertEqual(BUILD_REPO.stat().st_mode & 0o111, 0o111)


@unittest.skipUnless(
    shutil.which("rpmbuild") and shutil.which("createrepo_c") and shutil.which("rpmsign"),
    "rpm-build/createrepo_c/rpm-sign are not installed",
)
class RepoBuildTests(unittest.TestCase):
    def test_builds_a_signed_dnf_repository(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "repo"
            gpg_home = Path(tmp) / "gnupg"
            env = os.environ.copy()
            env["SENTINEL_GPG_HOME"] = str(gpg_home)
            result = subprocess.run(
                [str(BUILD_REPO), "--output", str(out)],
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            rpms = list(out.glob("sentinel-desktop-*.rpm"))
            self.assertTrue(rpms, result.stdout)
            self.assertTrue((out / "RPM-GPG-KEY-sentinel").is_file())
            self.assertTrue((out / "repodata/repomd.xml").is_file())
            self.assertTrue((out / "repodata/repomd.xml.asc").is_file())
            key = (out / "RPM-GPG-KEY-sentinel").read_text()
            self.assertIn("BEGIN PGP PUBLIC KEY BLOCK", key)
            rpmroot = Path(tmp) / "rpmroot"
            rpmroot.mkdir()
            imported = subprocess.run(
                ["rpmkeys", "--root", str(rpmroot), "--import", str(out / "RPM-GPG-KEY-sentinel")],
                capture_output=True,
                text=True,
            )
            self.assertEqual(imported.returncode, 0, imported.stderr)
            check = subprocess.run(
                ["rpmkeys", "--root", str(rpmroot), "--checksig", str(rpms[0])],
                capture_output=True,
                text=True,
            )
            self.assertEqual(check.returncode, 0, check.stderr)
            self.assertRegex(check.stdout, r"signatures OK|digests signatures OK")
            listing = subprocess.run(
                ["rpm", "-qlp", str(rpms[0])],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
            for path in (
                "/usr/share/sentinel-desktop/session/hyprland.lua",
                "/usr/share/sentinel-desktop/dot43pr/quickshell/shell.qml",
                "/usr/bin/sentinel-update",
                "/usr/share/wayland-sessions/sentinel.desktop",
                "/usr/share/fonts/sentinel/MaterialSymbolsOutlined.ttf",
                "/etc/pki/rpm-gpg/RPM-GPG-KEY-sentinel",
            ):
                self.assertIn(path, listing)


if __name__ == "__main__":
    unittest.main()
