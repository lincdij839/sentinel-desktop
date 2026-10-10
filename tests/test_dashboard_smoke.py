import os
import shutil
import subprocess
import unittest
from pathlib import Path

DASHBOARD = Path(__file__).resolve().parent.parent / "dashboard/Main.qml"
DASHBOARD_BODY = DASHBOARD.with_name("Dashboard.qml")


@unittest.skipUnless(shutil.which("quickshell"), "quickshell is not installed")
class DashboardSmokeTests(unittest.TestCase):
    def test_loads_offscreen_without_qml_errors(self) -> None:
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        if not os.access(runtime, os.W_OK):
            self.skipTest("XDG_RUNTIME_DIR is not writable")
        env = {**os.environ, "QT_QPA_PLATFORM": "offscreen"}
        try:
            result = subprocess.run(
                ["quickshell", "--path", str(DASHBOARD)],
                capture_output=True, text=True, env=env, timeout=4,
            )
            output = result.stdout + result.stderr
        except subprocess.TimeoutExpired as expired:
            # Still running after the timeout means the configuration loaded.
            output = (expired.stdout or b"").decode() + (expired.stderr or b"").decode()

        self.assertIn("Configuration Loaded", output)
        problems = [line for line in output.splitlines()
                    if "ERROR" in line or "Cannot assign" in line or "is not a type" in line]
        self.assertEqual(problems, [])

    def test_content_column_contains_footer(self) -> None:
        # Regression: an extra closing brace once pushed the footer and the
        # detail panel out of the content column, laying them out sideways.
        lines = DASHBOARD_BODY.read_text().splitlines()
        depth = 0
        depths = {}
        for line in lines:
            stripped = line.strip()
            if stripped.endswith("{") and stripped[0].isupper():
                depths.setdefault(stripped, []).append(depth)
            depth += line.count("{") - line.count("}")
        self.assertEqual(depth, 0)
        footer_parent_depth = depths["RowLayout {"][-1]
        content_depths = depths["ColumnLayout {"]
        self.assertIn(footer_parent_depth - 1, content_depths)


if __name__ == "__main__":
    unittest.main()
