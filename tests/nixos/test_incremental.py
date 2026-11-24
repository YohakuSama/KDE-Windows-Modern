#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/nixos-test-state.py"
spec = importlib.util.spec_from_file_location("wm_state", SCRIPT)
wm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wm)


class Incremental(unittest.TestCase):
    def test_payloads(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            src, dst = root / "source", root / "destination"
            src.mkdir()
            dst.mkdir()
            (src / "main.qml").write_text("new")
            (dst / "main.qml").write_text("old")
            self.assertFalse(wm.same_payload(src, dst))
            (dst / "main.qml").write_text("new")
            self.assertTrue(wm.same_payload(src, dst))
            (dst / "obsolete.qml").touch()
            self.assertFalse(wm.same_payload(src, dst))
            (dst / "obsolete.qml").unlink()
            (src / "empty").mkdir()
            self.assertFalse(wm.same_payload(src, dst))
            (dst / "empty").mkdir()
            self.assertTrue(wm.same_payload(src, dst))
            (dst / "main.qml").unlink()
            (dst / "main.qml").symlink_to(src / "main.qml")
            self.assertFalse(wm.same_payload(src, dst))
            self.assertFalse(wm.same_payload(src, root / "missing"))


if __name__ == "__main__":
    unittest.main()
