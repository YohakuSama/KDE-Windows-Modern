# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import sys
import tempfile
from pathlib import Path
from types import ModuleType
from unittest import TestCase
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
gi = ModuleType("gi")
gi.repository = ModuleType("gi.repository")
gi.repository.Gio = object()
gi.repository.GLib = object()
with patch.dict(sys.modules, {"gi": gi, "gi.repository": gi.repository}):
    spec = importlib.util.spec_from_file_location("clipboard_shortcut", ROOT / "scripts/windows-shortcuts.py")
    shortcuts = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shortcuts)


class Accel:
    aid = ["plasmashell", "show-on-mouse-pos", "Plasma", "Clipboard"]
    def __init__(self, initial=(), owner=None):
        self.values = list(initial)
        self.owner = owner or []
        self.writes = []
    def actions(self, component):
        return [self.aid] if component == self.aid[0] else []
    def keys(self, aid):
        return self.values[:]
    def key_owner(self, key):
        return self.owner
    def set_keys(self, aid, values):
        self.values = list(values)
        self.writes.append(self.values)


class ClipboardShortcutTests(TestCase):
    def test_native_action_and_backup(self):
        with tempfile.TemporaryDirectory() as d, patch.object(shortcuts, "BACKUP", Path(d) / "shortcuts.json"):
            old = shortcuts.parse("Ctrl+Alt+V")
            key = shortcuts.parse("Meta+V")
            ga = Accel([old])
            self.assertEqual(shortcuts.clipboard_target(ga), ga.aid)
            self.assertEqual(shortcuts.bind_clipboard(ga, ga.aid), 0)
            self.assertEqual(ga.keys(ga.aid), [old, key])
            self.assertEqual(shortcuts.load_backup(), {"plasmashell|show-on-mouse-pos": [old]})
            self.assertEqual(shortcuts.bind_clipboard(ga, ga.aid), 0)
            self.assertEqual(len(ga.writes), 1)
            backup = shortcuts.load_backup()
            self.assertEqual(shortcuts.restore_clipboard(ga, backup), 0)
            self.assertEqual(ga.keys(ga.aid), [old])
            self.assertEqual(backup, {})

    def test_existing_binding_and_conflict_are_not_changed(self):
        with tempfile.TemporaryDirectory() as d, patch.object(shortcuts, "BACKUP", Path(d) / "shortcuts.json"):
            ga = Accel([shortcuts.parse("Meta+V")])
            self.assertEqual(shortcuts.bind_clipboard(ga, ga.aid), 0)
            self.assertFalse(ga.writes)
            ga = Accel(owner=["other", "another-action", "", ""])
            self.assertEqual(shortcuts.bind_clipboard(ga, ga.aid), 1)
            self.assertFalse(ga.writes)
            self.assertFalse(shortcuts.BACKUP.exists())

    def test_missing_native_action_is_not_invented(self):
        ga = Accel()
        ga.actions = lambda component: []
        self.assertIsNone(shortcuts.clipboard_target(ga))
