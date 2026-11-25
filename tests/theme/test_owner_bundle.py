# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
from zipfile import ZipFile
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
verify = runpy.run_path(str(ROOT / "scripts/verify-owner-bundle.py"))["verify"]
SHA = "a" * 40


class OwnerBundleTests(unittest.TestCase):
    def test_undersized_bundle_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/INTEGRATION-BUILD", SHA)
            with self.assertRaisesRegex(ValueError, "minimum is 90000000"):
                verify(SHA, path)

    def test_large_size_alone_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/INTEGRATION-BUILD", SHA)
                z.writestr("theme/filler", "not a resource")
            with self.assertRaisesRegex(ValueError, "Missing/empty owner payload"):
                verify(SHA, path, min_bytes=1)

    def test_unsafe_paths_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/../escape", "x")
            with self.assertRaisesRegex(ValueError, "Invalid archive paths"):
                verify(SHA, path, min_bytes=1)
