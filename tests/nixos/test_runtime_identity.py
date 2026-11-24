#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/verify-nixos-runtime.py"
spec = importlib.util.spec_from_file_location("verifier", SCRIPT)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

class BuildIdentity(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.new = root / "new/systemtray.so"
        self.old = root / "old/systemtray.so"
        for path, token in ((self.new, "run.new"), (self.old, "run.old")):
            path.parent.mkdir()
            path.write_bytes(token.encode())
    def tearDown(self):
        self.tmp.cleanup()
    def mapping(self, path, deleted=False, inode=None, device=None):
        st = path.stat()
        if device is None:
            device = f"{os.major(st.st_dev):x}:{os.minor(st.st_dev):x}"
        return (f"0000-1000 r-xp 00000000 {device} "
                f"{st.st_ino if inode is None else inode} {path}" + (" (deleted)" if deleted else ""))
    def test_new(self):
        self.assertEqual(v.verify_plugin(self.new, "run.new", self.mapping(self.new)), self.new)
    def test_wrong_build_token(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.old, "run.new")
    def test_old_same_filename(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.new, "run.new", self.mapping(self.old))
    def test_mixed_versions(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.new, "run.new", self.mapping(self.new) + "\n" + self.mapping(self.old))
    def test_not_loaded(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.new, "run.new", "")
    def test_deleted_mapping(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.new, "run.new", self.mapping(self.new, deleted=True))
    def test_inode_mismatch_same_path(self):
        self.assertEqual(v.verify_plugin(self.new, "run.new", self.mapping(self.new, inode=self.new.stat().st_ino + 1)), self.new)
    def test_device_mismatch_same_path(self):
        self.assertEqual(v.verify_plugin(self.new, "run.new", self.mapping(self.new, device="ff:ff")), self.new)
    def test_both_mismatch_same_path(self):
        self.assertEqual(v.verify_plugin(self.new, "run.new", self.mapping(self.new, inode=1, device="ff:ff")), self.new)
    def test_metadata_mismatch_does_not_allow_old_path(self):
        with self.assertRaises(RuntimeError):
            v.verify_plugin(self.new, "run.new", self.mapping(self.old, inode=self.new.stat().st_ino, device="ff:ff"))

if __name__ == "__main__":
    unittest.main()
