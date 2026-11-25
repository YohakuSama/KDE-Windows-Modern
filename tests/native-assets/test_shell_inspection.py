# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import struct
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("shell_inspection", SCRIPTS / "inspect-shell-resources.py")
inspection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inspection)


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
