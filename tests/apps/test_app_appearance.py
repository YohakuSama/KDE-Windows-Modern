# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("app_appearance", ROOT / "scripts/app-appearance.py")
app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app)

class AppAppearanceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        app.DATA = Path(self.temp.name) / "share"
        app.CONFIG = Path(self.temp.name) / "config"
        app.STATE = Path(self.temp.name) / "state"
        app.BACKUP = app.DATA / "windows-modern/backup/app-appearance.json"
        self.values = {("konsolerc", "Desktop Entry", "DefaultProfile"): "My.profile"}
        app.read = lambda *args: self.values.get(args, app.MISSING)
        def write(file, group, key, value):
            if value == app.MISSING:
                self.values.pop((file, group, key), None)
            else:
                self.values[file, group, key] = value
        app.write = write

    def test_apply_and_restore(self):
        original = dict(self.values)
        app.apply()
        self.assertEqual(self.values["konsolerc", "Desktop Entry", "DefaultProfile"], "WindowsModern.profile")
        for relative, source in app.FILES.items():
            self.assertEqual((app.DATA / relative).read_bytes(), (ROOT / source).read_bytes())
        app.apply()
        app.restore()
        self.assertEqual(self.values, original)
        self.assertFalse(app.BACKUP.exists())
        for relative in app.FILES:
            self.assertFalse((app.DATA / relative).exists())

    def test_preserve_user_edits(self):
        app.apply()
        key = ("konsolerc", "TabBar", "NewTabButton")
        self.values[key] = "false"
        path = app.DATA / "konsole/WindowsModern.profile"
        path.write_text("my changed profile")
        app.apply()
        app.restore()
        self.assertEqual(self.values[key], "false")
        self.assertEqual(path.read_text(), "my changed profile")

    def test_custom_dolphin_layout(self):
        path = app.DATA / "kxmlgui5/dolphin/dolphinui.rc"
        path.parent.mkdir(parents=True)
        path.write_text("<gui name='custom'/>")
        app.apply()
        app.restore()
        self.assertEqual(path.read_text(), "<gui name='custom'/>")

    def test_terminal_both_toolbars_are_hidden_and_commands_remain(self):
        main = ET.parse(ROOT / app.FILES["kxmlgui5/konsole/konsoleui.rc"]).getroot()
        session = ET.parse(ROOT / app.FILES["kxmlgui5/konsole/sessionui.rc"]).getroot()
        for tree, name in ((main, "mainToolBar"), (session, "sessionToolbar")):
            bar = tree.find(f"ToolBar[@name='{name}']")
            self.assertIsNotNone(bar)
            self.assertEqual(bar.get("hidden"), "true")
            self.assertEqual(bar.findall("Action"), [])
        names = {a.get("name") for a in session.findall(".//MenuBar//Action")}
        self.assertTrue({"edit_copy", "edit_paste", "edit_find", "edit-current-profile"} <= names)
        self.assertIsNotNone(session.find(".//Menu[@name='session-popup-menu']/Action[@name='edit_find']"))

    def test_layout_revision_resets_regenerated_window_state_once(self):
        import json
        key = (str(app.STATE / "dolphinstaterc"), "MainWindow", "State")
        self.values[key] = "pre-theme-window-state"
        app.apply()
        # Simulate the prior theme XML and window state created by Qt.
        relative = "kxmlgui5/dolphin/dolphinui.rc"
        prior = b"<gui name='dolphin' version='49'/>"
        path = app.DATA / relative
        path.write_bytes(prior)
        backup = json.loads(app.BACKUP.read_text())
        backup["files"][relative]["applied"] = prior.hex()
        app.BACKUP.write_text(json.dumps(backup))
        self.values[key] = "generated-by-old-layout"
        app.apply()
        self.assertNotIn(key, self.values)
        self.values[key] = "generated-by-current-layout"
        app.apply()
        self.assertEqual(self.values[key], "generated-by-current-layout")
        self.values.pop(key)
        app.restore()
        self.assertEqual(self.values[key], "pre-theme-window-state")

    def test_custom_terminal_layout_preserves_visibility(self):
        path = app.DATA / "kxmlgui5/konsole/sessionui.rc"
        path.parent.mkdir(parents=True)
        path.write_text("<gui name='custom'/>")
        app.apply()
        self.assertEqual(self.values["konsolerc", "Desktop Entry", "DefaultProfile"], "My.profile")
        self.assertNotIn(("konsolerc", "MainWindow", "State"), self.values)
        self.assertEqual(path.read_text(), "<gui name='custom'/>")

    def test_terminal_state_migration_restores_original(self):
        key = (str(app.STATE / "konsolestaterc"), "MainWindow", "State")
        self.values[key] = "old-qt-toolbar-state"
        app.apply()
        self.assertNotIn(key, self.values)
        app.restore()
        self.assertEqual(self.values[key], "old-qt-toolbar-state")

    def test_explorer_layout_migration(self):
        key = (str(app.STATE / "dolphinstaterc"), "MainWindow", "State")
        self.values[key] = "old-dolphin-toolbar-state"
        app.apply()
        self.assertNotIn(key, self.values)
        self.assertEqual(self.values["dolphinrc", "General", "ShowStatusBar"], "FullWidth")
        root = ET.parse(ROOT / app.FILES["kxmlgui5/dolphin/dolphinui.rc"]).getroot()
        self.assertGreater(int(root.get("version")), 50)
        commands = {a.get("name") for a in root.findall("./ToolBar[@name='wmCommandToolBar']/Action")}
        self.assertTrue({"new_menu", "edit_cut", "edit_copy", "edit_paste", "renamefile", "movetotrash", "sort", "view_mode", "hamburger_menu"} <= commands)
        app.restore()
        self.assertEqual(self.values[key], "old-dolphin-toolbar-state")

    def test_reference_layout_and_aliases(self):
        root = ET.parse(ROOT / app.FILES["kxmlgui5/dolphin/dolphinui.rc"]).getroot()
        bars = root.findall("ToolBar")
        self.assertEqual([bar.get("name") for bar in bars], ["mainToolBar", "wmCommandToolBar"])
        self.assertEqual(bars[1].get("newline"), "true")
        self.assertEqual([a.get("name") for a in bars[0].findall("Action")][:4],
                         ["go_back", "go_forward", "go_up", "redisplay"])
        icons = ROOT / "icons/windows-modern/apps"
        original = (icons / "discover.svg").read_bytes()
        ET.fromstring(original)
        for alias in ("org.kde.discover", "plasmadiscover", "muondiscover", "plasma-discover"):
            self.assertEqual(original, (icons / (alias + ".svg")).read_bytes())
