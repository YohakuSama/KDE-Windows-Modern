#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reproduce Nix store mode 0555/0444 without needing a NixOS desktop."""
import importlib.util
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "scripts/nixos-test-state.py"
spec = importlib.util.spec_from_file_location("wm_state", MODULE)
wm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wm)


class Permissions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        wm.DATA = self.root / "data"
        wm.CONFIG = self.root / "config"
        wm.DATA.mkdir()
        wm.CONFIG.mkdir()
        self.source = self.root / "store" / "Bibata-Modern-Ice"
        self.source.mkdir(parents=True)
        (self.source / "cursors").mkdir()
        (self.source / "cursors/left_ptr").write_text("cursor")
        self.external = self.root / "store" / "outside"
        self.external.write_text("untouched")
        self.external.chmod(0o444)
        (self.source / "cursors/alias").symlink_to(self.external)
        (self.source / "cursors/left_ptr").chmod(0o444)
        (self.source / "cursors").chmod(0o555)
        self.source.chmod(0o555)
        self.dst = wm.DATA / "icons/Bibata-Modern-Ice"
        self.dst.parent.mkdir()

    def tearDown(self):
        wm.remove(self.root)
        self.tmp.cleanup()

    def mode(self, path):
        return stat.S_IMODE(path.stat().st_mode)

    def test_install_readonly_store_package(self):
        wm.replace(self.source, self.dst, writable=True)
        self.assertTrue(self.mode(self.dst) & stat.S_IWUSR)
        self.assertTrue(self.mode(self.dst / "cursors/left_ptr") & stat.S_IWUSR)
        self.assertEqual(self.mode(self.source), 0o555)
        self.assertEqual(self.mode(self.external), 0o444)
        self.assertTrue((self.dst / "cursors/alias").is_symlink())
        self.assertEqual(list(self.dst.parent.glob(".wm-test-*")), [])

    def test_restore_readonly_original_exact_modes(self):
        wm.replace(self.source, self.dst)
        self.assertEqual(self.mode(self.dst), 0o555)
        self.assertEqual(self.mode(self.dst / "cursors/left_ptr"), 0o444)
        wm.replace(self.source, self.dst, writable=True)
        wm.replace(self.source, self.dst)
        self.assertEqual(self.mode(self.dst), 0o555)
        self.assertEqual(list(self.dst.parent.glob(".wm-test-*")), [])

    def test_failed_rename_restores_previous(self):
        wm.replace(self.source, self.dst)
        replacement = self.root / "replacement"
        replacement.mkdir()
        (replacement / "different").write_text("new")
        original_rename = Path.rename
        def fail_new(path, target):
            if path.name.endswith("-new"):
                raise PermissionError("injected install failure")
            return original_rename(path, target)
        with patch.object(Path, "rename", fail_new):
            with self.assertRaises(PermissionError):
                wm.replace(replacement, self.dst, writable=True)
        self.assertEqual((self.dst / "cursors/left_ptr").read_text(), "cursor")
        self.assertEqual(self.mode(self.dst), 0o555)
        self.assertEqual(list(self.dst.parent.glob(".wm-test-*")), [])

    def test_remove_readonly_logout_and_symlink(self):
        state = self.root / "state"
        logout = state / "staged-shell/contents/logout"
        logout.mkdir(parents=True)
        (logout / "Logout.qml").write_text("logout")
        (logout / "Logout.qml").chmod(0o444)
        (logout / "store-link").symlink_to(self.source, target_is_directory=True)
        logout.chmod(0o555)
        wm.remove(state)
        self.assertFalse(state.exists())
        self.assertEqual(self.mode(self.source), 0o555)
        self.assertTrue((self.source / "cursors/left_ptr").exists())

    def test_restore_symlink_without_touching_target(self):
        original = self.root / "original-link"
        original.symlink_to(self.external)
        wm.replace(self.source, self.dst, writable=True)
        wm.replace(original, self.dst)
        self.assertTrue(self.dst.is_symlink())
        self.assertEqual(self.mode(self.external), 0o444)
        wm.remove(self.dst)
        self.assertTrue(self.external.exists())


if __name__ == "__main__":
    if os.geteuid() == 0:
        raise SystemExit("Run as an ordinary user to exercise Linux permissions")
    unittest.main(verbosity=2)
