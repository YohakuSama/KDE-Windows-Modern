# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys

from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("shell_assets", SCRIPTS / "import-shell-assets.py")
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


def png():
    stream = io.BytesIO()
    Image.new("RGBA", (24, 24), (0, 100, 200, 255)).save(stream, format="PNG")
    return stream.getvalue()


class ShellAssetTests(unittest.TestCase):
    def test_search_selects_highest_scale_and_preserves_original(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for scale in (100, 200):
                (root / f"SearchIconOnDark.scale-{scale}.png").write_bytes(png())
            path, data, scale = assets.search_artwork(root, root, "dark", "on")
            self.assertEqual(scale, 200)
            self.assertEqual(data, path.read_bytes())
            with self.assertRaisesRegex(ValueError, "Missing original"):
                assets.search_artwork(root, root, "light", "off")

    def test_case_insensitive_resource_path(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "Windows").mkdir()
            self.assertEqual(assets.local_file(root, "windows"), root / "Windows")
            self.assertIsNone(assets.local_file(root, "missing"))

    def test_svg_safety(self):
        assets.validate_svg(b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L1 1"/></svg>')
        for payload in (
            b'<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>',
            b'<svg xmlns="http://www.w3.org/2000/svg"><path fill="url(https://example.org/a)"/></svg>',
            b'<svg xmlns="http://www.w3.org/2000/svg" onload="x"/>',
        ):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                assets.validate_svg(payload)

    def test_output_is_atomic_and_preserves_prior_import_on_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, destination = root / "Windows", root / "shell-assets"
            source.mkdir()
            image = png()
            outputs = {"search/dark-on.png": (image, {"source": "original.png",
                        "resource": "scale-100", "sha256": assets.sha256(image)})}
            with patch.object(assets, "collect", return_value=(outputs, {})):
                manifest = assets.install(source, destination, "26300")
            self.assertEqual(manifest["declared_source_build"], "26300")
            with patch.object(assets, "collect", side_effect=ValueError("missing original")):
                with self.assertRaisesRegex(ValueError, "missing original"):
                    assets.install(source, destination, "26301")
            self.assertEqual((destination / "search/dark-on.png").read_bytes(), image)
            self.assertIn('"26300"', (destination / "manifest.json").read_text())

    def test_never_overwrites_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, destination = root / "Windows", root / "shell-assets"
            source.mkdir()
            destination.mkdir()
            with patch.object(assets, "collect", return_value=({}, {})):
                with self.assertRaisesRegex(ValueError, "unrelated"):
                    assets.install(source, destination, "26300")


if __name__ == "__main__":
    unittest.main()
