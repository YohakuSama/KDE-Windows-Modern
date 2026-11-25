# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("wallpaper_check", ROOT / "scripts/check-native-wallpaper.py")
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class WallpaperIntegrityTests(unittest.TestCase):
    def test_source_bytes_and_no_unlisted_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            package = root / "wallpapers/Windows-modern"
            image = package / "contents/images/1920x1080.jpg"
            image.parent.mkdir(parents=True)
            original = b"original image bytes"
            image.write_bytes(original)
            digest = hashlib.sha256(original).hexdigest()
            blob = hashlib.sha1(b"blob " + str(len(original)).encode() + b"\0" + original).hexdigest()
            source = "Web/Wallpaper/Windows/img0.jpg"
            (package / "metadata.json").write_text(json.dumps({"KPlugin": {
                "Id": "Windows-modern", "Description": "Local Windows reference image"
            }}))
            (root / "manifest.json").write_text(json.dumps({
                "sources": {source: {"sha256": digest, "bytes": len(original)}},
                "outputs": {image.relative_to(root).as_posix(): {"source": source, "sha256": digest}}
            }))
            mapping = {"wallpapers": [["Windows-modern", "Bloom", source, None]]}
            expected = {source: blob}
            self.assertEqual(check.verify_package(root, package, "Windows-modern", mapping, expected), 1)
            image.write_bytes(b"cropped wallpaper")
            with self.assertRaisesRegex(ValueError, "differ from original"):
                check.verify_package(root, package, "Windows-modern", mapping, expected)
            image.write_bytes(original)
            with self.assertRaisesRegex(ValueError, "pinned owner resource"):
                check.verify_package(root, package, "Windows-modern", mapping, {source: "wrong"})
            (image.parent / "compatibility.png").write_bytes(b"extra")
            with self.assertRaisesRegex(ValueError, "Unexpected wallpaper files"):
                check.verify_package(root, package, "Windows-modern", mapping, expected)
