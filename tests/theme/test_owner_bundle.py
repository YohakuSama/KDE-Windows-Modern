# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
from zipfile import ZipFile
import hashlib
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
checker = runpy.run_path(str(ROOT / "scripts/verify-owner-bundle.py"))
verify = checker["verify"]
verify_resource_index = checker["verify_resource_index"]
SHA = "a" * 40


class OwnerBundleTests(unittest.TestCase):
    def test_incomplete_bundle_fails_regardless_of_size(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/INTEGRATION-BUILD", SHA)
            with self.assertRaisesRegex(ValueError, "Missing/empty owner payload"):
                verify(SHA, path)

    def test_large_size_alone_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/INTEGRATION-BUILD", SHA)
                z.writestr("theme/filler", "not a resource")
            with self.assertRaisesRegex(ValueError, "Missing/empty owner payload"):
                verify(SHA, path)

    def test_unsafe_paths_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "owner.zip"
            with ZipFile(path, "w") as z:
                z.writestr("theme/../escape", "x")
            with self.assertRaisesRegex(ValueError, "Invalid archive paths"):
                verify(SHA, path)

    def test_index_checks_selected_files_and_rejects_unused_ones(self):
        original = "original/Windows/Fonts/SegoeIcons.ttf"
        png = "png/example/1.png"
        unused = "original/Windows/Fonts/unused.ttf"
        contents = b"resource bytes"
        digest = hashlib.sha256(contents).hexdigest()
        mapping = {"libraries": {"i": "example"}, "wallpapers": [],
                   "sounds": {}, "icons": {"i:1": "actions/example"}}
        index = {
            "original_files": [{"path": original, "sha256": digest, "size_bytes": len(contents)},
                               {"path": unused, "sha256": digest, "size_bytes": len(contents)}],
            "groups": [{"module": "example", "group_id": 1, "language_id": 1033,
                        "preview_png": png, "frames": [{"png": png, "png_sha256": digest}]}],
        }
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "index.zip"
            for case in ("complete", "wrong bytes", "missing preview", "extra font"):
                with self.subTest(case=case):
                    with ZipFile(path, "w") as z:
                        z.writestr("native/" + original, contents)
                        if case != "missing preview":
                            z.writestr("native/" + png, contents if case != "wrong bytes" else b"incorrect bytes")
                        if case == "extra font":
                            z.writestr("native/" + unused, contents)
                    with ZipFile(path) as z:
                        if case == "complete":
                            self.assertEqual(verify_resource_index(z, "native/", index, mapping), 2)
                        else:
                            with self.assertRaisesRegex(ValueError, "hash mismatch|Missing indexed|Unused native"):
                                verify_resource_index(z, "native/", index, mapping)

    def test_development_payload_rejected(self):
        for name in ("tests/run-qml-tests.sh", "plasma/applets/demo/tests/test.cpp",
                     "docs/WINDOWS11_FIDELITY.md", "scripts/ci-build.sh", "View-1.png"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / "owner.zip"
                with ZipFile(path, "w") as z:
                    z.writestr("theme/INTEGRATION-BUILD", SHA)
                    z.writestr("theme/" + name, "development only")
                with self.assertRaisesRegex(ValueError, "Development payload"):
                    verify(SHA, path)
