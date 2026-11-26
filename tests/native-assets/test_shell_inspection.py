# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import Mock

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("shell_inspection", SCRIPTS / "inspect-shell-resources.py")
inspection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inspection)


class NamedResources(unittest.TestCase):
    def test_numeric_and_named_resources(self):
        from native_pe_resources import pe_resources
        data = bytearray(0x500)
        data[:2] = b'MZ'
        struct.pack_into('<I', data, 0x3c, 0x80)
        data[0x80:0x84] = b'PE\0\0'
        struct.pack_into('<H', data, 0x86, 1)
        struct.pack_into('<H', data, 0x94, 0xe0)
        struct.pack_into('<H', data, 0x98, 0x10b)
        struct.pack_into('<I', data, 0x98 + 96 + 16, 0x1000)
        struct.pack_into('<III', data, 0x178 + 12, 0x1000, 0x300, 0x200)
        base = 0x200

        def directory(rel, named_count, id_count, entries):
            struct.pack_into('<HH', data, base + rel + 12, named_count, id_count)
            for i, (name, child) in enumerate(entries):
                struct.pack_into('<II', data, base + rel + 16 + 8 * i, name, child)

        directory(0, 0, 1, [(14, 0x80000020)])
        directory(0x20, 1, 1, [(0x800000a0, 0x80000050), (7, 0x80000070)])
        directory(0x50, 0, 1, [(1033, 0xb0)])
        directory(0x70, 0, 1, [(0, 0xc0)])
        struct.pack_into('<H', data, base + 0xa0, 7)
        data[base + 0xa2:base + 0xb0] = 'Battery'.encode('utf-16le')
        struct.pack_into('<II', data, base + 0xb0, 0x1100, 3)
        struct.pack_into('<II', data, base + 0xc0, 0x1103, 3)
        data[0x300:0x306] = b'abcdef'
        self.assertEqual(pe_resources(data), {(14, 7, 0): b'def'})
        self.assertEqual(pe_resources(data, named=True),
                         {(14, 'Battery', 1033): b'abc', (14, 7, 0): b'def'})


class IconGroup(unittest.TestCase):
    def setUp(self):
        self.group = (14, "Battery", 1033)
        self.entry = struct.pack("<BBBBHHIH", 0, 0, 0, 0, 1, 32, 3, 42)
        self.resources = {self.group: struct.pack("<HHH", 0, 1, 1) + self.entry, (3, 42, 0): b"abc"}

    def test_single_language_fallback_preserves_frame(self):
        ico, frames = inspection.icon_group(self.resources, self.group)
        self.assertEqual(ico[22:], b"abc")
        self.assertEqual(struct.unpack_from("<I", ico, 18)[0], 22)
        self.assertEqual((frames[0]["width"], frames[0]["id"], frames[0]["language"]), (256, 42, 0))

    def test_exact_language_and_ambiguous_fallback(self):
        self.resources[(3, 42, 1041)] = b"def"
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            inspection.icon_group(self.resources, self.group)
        self.resources[(3, 42, 1033)] = b"ghi"
        self.assertEqual(inspection.icon_group(self.resources, self.group)[0][22:], b"ghi")

    def test_size_mismatch(self):
        self.resources[(3, 42, 0)] = b"shorter than declared?"
        with self.assertRaisesRegex(ValueError, "length"):
            inspection.icon_group(self.resources, self.group)


class FontReviewGlyph(unittest.TestCase):
    def test_mask_centers_visible_pixels_without_text_shaping(self):
        from PIL import Image

        mask = Image.new("L", (8, 10))
        mask.paste(255, (1, 2, 5, 8))
        font = Mock()
        font.getmask.return_value = mask.im
        tile = Image.new("RGB", (84, 76), "white")
        self.assertTrue(inspection.draw_review_glyph(tile, font, 0xE700, 52))
        font.getmask.assert_called_once_with(chr(0xE700), mode="L")
        self.assertEqual(tile.getpixel((40, 23)), (0, 0, 0))
        self.assertEqual(tile.getpixel((39, 23)), (255, 255, 255))
        self.assertEqual(tile.getpixel((40, 29)), (255, 255, 255))

    def test_blank_mask_does_not_create_a_replacement_glyph(self):
        from PIL import Image

        font = Mock()
        font.getmask.return_value = Image.new("L", (8, 10)).im
        tile = Image.new("RGB", (84, 76), "white")
        self.assertFalse(inspection.draw_review_glyph(tile, font, 0x20, 52))
        self.assertEqual(tile.getextrema(), ((255, 255), (255, 255), (255, 255)))
