# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise recovery helpers with failing user services, without a desktop."""
import re
import subprocess
import tempfile
from pathlib import Path
import unittest

SCRIPT = (Path(__file__).resolve().parents[2] / "install-nixos.sh").read_text()


def helper(name):
    match = re.search(r"(?ms)^" + re.escape(name) + r"\(\)\s*\{.*?^\}", SCRIPT)
    if not match:
        raise AssertionError("Missing recovery helper: " + name)
    return match.group()


class Recovery(unittest.TestCase):
    def shell(self, names, body, *args):
        return subprocess.run(
            ["bash", "-c", "set -Eeuo pipefail\n" + "\n".join(map(helper, names)) + "\n" + body,
             "recovery-test", *map(str, args)], capture_output=True, text=True, check=True
        ).stdout.splitlines()

    def test_failed_start_is_not_masked_by_existing_bus(self):
        lines = self.shell(["start_shell"], """
SERVICE=plasma-plasmashell.service
systemctl() { echo start; return 1; }
wait_shell() { echo stale-bus; return 0; }
if start_shell; then echo unexpected-success; else echo failure; fi
""")
        self.assertEqual(lines, ["start", "failure"])

    def test_successful_start_waits_for_service(self):
        lines = self.shell(["start_shell"], """
SERVICE=plasma-plasmashell.service
systemctl() { echo start; }
wait_shell() { echo wait; return 0; }
if start_shell; then echo success; fi
""")
        self.assertEqual(lines, ["start", "wait", "success"])

    def test_restore_env_preserves_failure_and_attempts_all_keys(self):
        with tempfile.TemporaryDirectory() as tmp:
            saved = Path(tmp) / "env"
            saved.write_text("QT_PLUGIN_PATH=/old/plugin\nQML_DISABLE_DISK_CACHE=0\n")
            lines = self.shell(["restore_env"], """
STATE=/unused
systemctl() {
    printf '%s\\n' "$*"
    if [[ "$*" == *QT_PLUGIN_PATH* ]]; then return 1; fi
    return 0
}
if restore_env "$1"; then echo unexpected-success; else echo failure; fi
""", saved)
            self.assertEqual(lines, [
                "--user set-environment QT_PLUGIN_PATH=/old/plugin",
                "--user unset-environment XDG_DATA_DIRS",
                "--user set-environment QML_DISABLE_DISK_CACHE=0", "failure"
            ])

    def test_publish_marker_after_rollback_trap(self):
        trap = SCRIPT.index("then rollback \"$rc\"; fi' EXIT")
        marker = SCRIPT.index('mv -T -- "$BUILD_DIR/pending-marker" "$STATE/pending-build"')
        self.assertLess(trap, marker)

    def test_retry_uses_uninstall_menu(self):
        self.assertIn("请重新运行选项 3", SCRIPT)
        self.assertNotIn("请重新运行选项 2", SCRIPT)


if __name__ == "__main__":
    unittest.main()
