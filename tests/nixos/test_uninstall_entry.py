# SPDX-License-Identifier: GPL-3.0-or-later
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class UninstallEntry(unittest.TestCase):
    def test_os_release_selects_only_one_installer(self):
        # Only the dispatcher runs. Both destinations exit before touching a desktop.
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copyfile(ROOT / "uninstall.sh", root / "uninstall.sh")
            (root / "scripts").mkdir()
            (root / "scripts/install-lib.sh").write_text('echo generic; exit 0\n')
            (root / "install-nixos.sh").write_text('echo "nixos $*"; exit 0\n')
            (root / "grep").write_text(
                '#!/bin/sh\nexec /usr/bin/grep "$1" "$2" "$TEST_OS_RELEASE"\n'
            )
            (root / "grep").chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", TEST_OS_RELEASE=str(root / "os-release"))
            for release, expected in [('ID="nixos"', "nixos uninstall"), ("ID=nixos", "nixos uninstall"), ("ID=fedora", "generic")]:
                with self.subTest(release=release):
                    (root / "os-release").write_text(release + "\n")
                    result = subprocess.run(["bash", root / "uninstall.sh"], env=env, capture_output=True, text=True, check=True)
                    self.assertEqual(result.stdout.strip(), expected)
