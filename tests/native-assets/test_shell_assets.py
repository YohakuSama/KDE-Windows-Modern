# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys

from PIL import Image
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("shell_assets", SCRIPTS / "import-shell-assets.py")
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


def png():
    stream = io.BytesIO()
    Image.new("RGBA", (24, 24), (0, 100, 200, 255)).save(stream, format="PNG")
    return stream.getvalue()


def fixture_font(codes):
    """Synthetic test-only outlines; never part of the installed artwork."""
    builder = FontBuilder(2048, isTTF=True)
    glyph_names = [".notdef"] + [f"g{code:04x}" for code in sorted(codes)]
    builder.setupGlyphOrder(glyph_names)
    builder.setupCharacterMap({code: f"g{code:04x}" for code in codes})
    glyphs = {}
    for name in glyph_names:
        pen = TTGlyphPen(None)
        pen.moveTo((128, 512))
        pen.lineTo((2304, 512))
        pen.lineTo((2304, 1536))
        pen.lineTo((128, 1536))
        pen.closePath()
        glyphs[name] = pen.glyph()
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics({name: (2560, 128) for name in glyph_names})
    builder.setupHorizontalHeader(ascent=2048, descent=0)
    builder.setupNameTable({"familyName": "SysBatt Fluent Icons",
                            "styleName": "Regular", "uniqueFontIdentifier": "Test fixture",
                            "fullName": "SysBatt Fluent Icons", "psName": "SysBattTest"})
    builder.setupOS2(sTypoAscender=2048, sTypoDescender=0, usWinAscent=2048, usWinDescent=0)
    builder.setupPost()
    stream = io.BytesIO()
    builder.save(stream)
    return stream.getvalue()


class ShellAssetTests(unittest.TestCase):
    def test_battery_exports_original_paths_on_shared_canvas(self):
        result = list(assets.battery_artwork(fixture_font(assets.BATTERY_CODES)))
        self.assertEqual(len(result), len(assets.BATTERY_CODES))
        for path, svg, code in result:
            with self.subTest(code=code):
                self.assertTrue(path.endswith(".svg"))
                self.assertIn(b'viewBox="0 0 2560 2048"', svg)
                self.assertIn(b'translate(0 2048) scale(1 -1)', svg)
                self.assertIn(b'd="M128 512H2304V1536H128Z"', svg)
        with self.assertRaisesRegex(ValueError, "Missing SysBatt glyphs"):
            list(assets.battery_artwork(fixture_font({0xf8d0})))

    def test_search_selects_highest_scale_and_preserves_original(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for scale in (100, 200):
                (root / f"SearchIconOnDark.scale-{scale}.png").write_bytes(png())
            path, data, scale = assets.search_artwork(root, root, "dark", "on")
            self.assertEqual(scale, 200)
            self.assertEqual(data, path.read_bytes())
            with self.assertRaisesRegex(ValueError, "Missing original"):
                assets.search_artwork(root, root, "light", "off", required=True)
            self.assertIsNone(assets.search_artwork(root, root, "dark", "off", required=False))

    def test_case_insensitive_resource_path(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "Windows").mkdir()
            self.assertEqual(assets.local_file(root, "windows"), root / "Windows")
            self.assertIsNone(assets.local_file(root, "missing"))

    def test_svg_safety(self):
        assets.validate_svg(b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L1 1"/></svg>')
        assets.validate_svg(b'<svg xmlns="http://www.w3.org/2000/svg"><path fill="url(#paint)"/></svg>')
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
