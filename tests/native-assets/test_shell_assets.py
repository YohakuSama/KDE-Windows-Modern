# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
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
    def test_battery_font_exports_every_verified_state_as_svg(self):
        class NameRecord:
            nameID = 1
            def toUnicode(self):
                return "SysBatt Fluent Icons"

        class Glyph:
            def draw(self, pen):
                pen.moveTo((0, 0))
                pen.lineTo((1000, 0))
                pen.lineTo((1000, 1500))
                pen.closePath()

        class FakeFont:
            def __init__(self, codes):
                self.codes = codes
                self.name = SimpleNamespace(names=[NameRecord()])
                self.head = SimpleNamespace(unitsPerEm=2048)
                self.hhea = SimpleNamespace(ascent=1900)
                self.hmtx = {f"glyph-{code:x}": (2560, 0) for code in codes}
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                return False
            def __getitem__(self, key):
                return {"name": self.name, "head": self.head,
                        "hhea": self.hhea, "hmtx": self.hmtx}[key]
            def getBestCmap(self):
                return {code: f"glyph-{code:x}" for code in self.codes}
            def getGlyphSet(self):
                return {f"glyph-{code:x}": Glyph() for code in self.codes}

        with patch.object(assets, "TTFont", return_value=FakeFont(assets.BATTERY_CODES)):
            exported = list(assets.battery_artwork(b"font-bytes"))
        self.assertEqual(len(exported), len(assets.BATTERY_CODES))
        by_path = {name: (svg, code) for name, svg, code in exported}
        for code in assets.BATTERY_CODES:
            name = f"battery/{code:04x}.svg"
            self.assertIn(name, by_path)
            svg, label = by_path[name]
            self.assertIn(b'viewBox="0 0 2560 2048"', svg)
            self.assertIn(b'<path fill="#ffffff"', svg)
            self.assertEqual(label, f"U+{code:04X}")

        missing = set(assets.BATTERY_CODES) - {0xf8d0}
        with patch.object(assets, "TTFont", return_value=FakeFont(missing)):
            with self.assertRaisesRegex(ValueError, "Missing SysBatt glyphs"):
                list(assets.battery_artwork(b"font-bytes"))

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
            self.assertIsNone(
                assets.search_artwork(root, root, "dark", "off", required=False)
            )

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
