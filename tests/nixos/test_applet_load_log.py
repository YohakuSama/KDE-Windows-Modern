# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("load_log", ROOT / "scripts/check-applet-load-log.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AppletLoadLogTest(unittest.TestCase):
    def test_reported_errors_are_fatal(self):
        errors = [
            'qrc:/qt/qml/plasma/applet/org/kde/windowsmodern/systemtray/main.qml:365:13: Cannot assign object of type "Connections" to property of type "QQuickItem*"',
            'file:///home/user/.local/share/plasma/plasmoids/org.kde.windowsmodern.digitalclock/contents/ui/main.qml:87:9: Cannot assign to non-existent property "popupBlacklistedNotifyRcNames"',
            'file:///home/user/.local/share/plasma/plasmoids/org.kde.windowsmodern.startmenu/contents/ui/main.qml:10: Type MenuRepresentation unavailable',
        ]
        self.assertEqual(MODULE.fatal_lines(errors), errors)

    def test_unrelated_warnings_and_shell_noise_are_ignored(self):
        lines = [
            'qrc:/qt/qml/plasma/applet/org/kde/windowsmodern/systemtray/main.qml:30: QML binding loop',
            'qrc:/qt/qml/plasma/applet/org/kde/plasma/other/main.qml:5: Cannot assign to non-existent property "foo"',
            'WM_POPUP tray OK 360 500',
        ]
        self.assertEqual(MODULE.fatal_lines(lines), [])
