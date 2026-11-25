// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.icontasks/contents/ui/code/JumpListPolicy.js" as Policy

TestCase {
    name: "JumpListPolicy"
    function test_expandedMenuModifier() {
        verify(!Policy.expandedFromModifiers(Qt.NoModifier, Qt.ShiftModifier));
        verify(!Policy.expandedFromModifiers(Qt.ControlModifier, Qt.ShiftModifier));
        verify(Policy.expandedFromModifiers(Qt.ShiftModifier, Qt.ShiftModifier));
        verify(Policy.expandedFromModifiers(Qt.ShiftModifier | Qt.ControlModifier, Qt.ShiftModifier));
    }
    function test_launcherActions_data() {
        return [
            {tag: "running unpinned", url: true, startup: false, locked: false, pinned: false, count: 1, pin: true, unpin: false, chooser: false},
            {tag: "running or pinned launcher", url: true, startup: false, locked: false, pinned: true, count: 1, pin: false, unpin: true, chooser: false},
            {tag: "no launcher", url: false, startup: false, locked: false, pinned: false, count: 1, pin: false, unpin: false, chooser: false},
            {tag: "startup", url: true, startup: true, locked: false, pinned: true, count: 1, pin: false, unpin: false, chooser: false},
            {tag: "locked panel", url: true, startup: false, locked: true, pinned: false, count: 1, pin: false, unpin: false, chooser: false},
            {tag: "multiple activities", url: true, startup: false, locked: false, pinned: true, count: 2, pin: false, unpin: false, chooser: true},
            {tag: "multiple activities missing launcher", url: false, startup: false, locked: false, pinned: true, count: 2, pin: false, unpin: false, chooser: false}
        ];
    }
    function test_launcherActions(data) {
        const result = Policy.launcherActions(data.url, data.startup, data.locked, data.pinned, data.count);
        compare(result.pin, data.pin);
        compare(result.unpin, data.unpin);
        compare(result.perActivity, data.chooser);
    }
}
