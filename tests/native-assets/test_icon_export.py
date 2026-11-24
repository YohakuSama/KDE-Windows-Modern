# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import struct
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("export_windows_icons", SCRIPTS / "export-windows-icons.py")
export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export)


class IconExportTests(unittest.TestCase):
    def resources(self):
        frames = [(16, 16, 0, 0, 1, 32, 3, 20), (0, 0, 0, 0, 1, 32, 4, 21)]
        group = struct.pack("<HHH", 0, 1, len(frames)) + b"".join(
            struct.pack("<BBBBHHIH", *f) for f in frames
        )
        return {(14, 9, 1033): group, (3, 20, 1033): b"abc",
                (3, 20, 0): b"bad", (3, 21, 0): b"defg"}

    def test_ico_preserves_all_original_payloads_and_dimensions(self):
        frames = export.group_frames(self.resources(), (14, 9, 1033))
        ico = export.make_ico(frames)
        self.assertEqual(struct.unpack_from("<HHH", ico), (0, 1, 2))
        one = struct.unpack_from("<BBBBHHII", ico, 6)
        two = struct.unpack_from("<BBBBHHII", ico, 22)
        self.assertEqual(one, (16, 16, 0, 0, 1, 32, 3, 38))
        self.assertEqual(two, (0, 0, 0, 0, 1, 32, 4, 41))
        self.assertEqual(ico[one[-1]:two[-1]], b"abc")
        self.assertEqual(ico[two[-1]:], b"defg")
        self.assertEqual([f["language"] for f in frames], [1033, 0])

    def test_missing_frame_fails(self):
        resources = self.resources()
        del resources[(3, 21, 0)]
        with self.assertRaisesRegex(ValueError, "Missing RT_ICON"):
            export.group_frames(resources, (14, 9, 1033))

    def test_wrong_length_fails(self):
        resources = self.resources()
        resources[(3, 20, 1033)] = b"wrong"
        with self.assertRaisesRegex(ValueError, "Invalid RT_ICON length"):
            export.group_frames(resources, (14, 9, 1033))
