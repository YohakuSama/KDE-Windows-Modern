# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("desktop_contextmenu", ROOT / "scripts/desktop-contextmenu.py")
MENU = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MENU)


class ContextMenuConfigTests(unittest.TestCase):
    def test_preserve_stock_gestures_without_explicit_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            stock = root / "defaults"
            stock.write_text("[Desktop][ContainmentActions]\nRightButton;NoModifier=org.kde.contextmenu\nMiddleButton;NoModifier=org.kde.paste\n")
            self.assertEqual(MENU.changes(root / "layout", stock), {
                MENU.KEY: MENU.PLUGIN, "MiddleButton;NoModifier": "org.kde.paste"})

    def test_only_change_existing_right_click(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            layout = root / "layout"
            layout.write_text("[ActionPlugins][0]\nMiddleButton;NoModifier=my.custom\n[ActionPlugins][1]\nRightButton;NoModifier=org.kde.contextmenu\n")
            self.assertEqual(MENU.changes(layout, root / "defaults"), {MENU.KEY: MENU.PLUGIN})

    def test_reset_uses_custom_shell_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "stock"
            destination = root / "overlay"
            before = ("[Desktop][ContainmentActions]\n"
                      "RightButton;NoModifier=org.kde.contextmenu\n"
                      "MiddleButton;NoModifier=org.kde.paste\n"
                      "[Panel][ContainmentActions]\n"
                      "RightButton;NoModifier=org.kde.contextmenu\n")
            source.write_text(before, encoding="utf-8")
            MENU.patch_defaults(source, destination)
            self.assertEqual(source.read_text(encoding="utf-8"), before)
            self.assertEqual(destination.read_text(encoding="utf-8"),
                             before.replace("org.kde.contextmenu", MENU.PLUGIN, 1))
            self.assertEqual(MENU.changes(root / "reset-layout", destination)[MENU.KEY], MENU.PLUGIN)
            invalid = root / "invalid"
            invalid.write_text("[Desktop]\nContainment=org.kde.plasma.folder\n", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                MENU.patch_defaults(invalid, destination)
