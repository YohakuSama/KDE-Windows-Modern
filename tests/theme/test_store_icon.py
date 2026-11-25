# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ICON_DIR = ROOT / "icons" / "windows-modern" / "apps"
NAMES = (
    "discover.svg",
    "org.kde.discover.svg",
    "plasma-discover.svg",
    "plasmadiscover.svg",
)


class StoreIconTests(unittest.TestCase):
    def test_all_discover_names_use_the_same_current_artwork(self):
        contents = [(ICON_DIR / name).read_bytes() for name in NAMES]
        self.assertTrue(all(content == contents[0] for content in contents[1:]))

    def test_store_icon_is_white_bag_with_cyan_handle_and_four_colour_mark(self):
        root = ET.fromstring((ICON_DIR / NAMES[0]).read_text())
        self.assertEqual(root.attrib.get("viewBox"), "0 0 48 48")
        ns = {"svg": "http://www.w3.org/2000/svg"}
        paths = root.findall("svg:path", ns)
        self.assertGreaterEqual(len(paths), 6)
        fills = {node.attrib.get("fill", "").upper() for node in root.iter()}
        strokes = {node.attrib.get("stroke", "").upper() for node in root.iter()}
        self.assertIn("#00A4EF", strokes)
        self.assertTrue({"#F25022", "#7FBA00", "#00A4EF", "#FFB900"}.issubset(fills))
        self.assertNotIn("#1677B6", fills)
        self.assertNotIn("#183B70", fills)


if __name__ == "__main__":
    unittest.main()
