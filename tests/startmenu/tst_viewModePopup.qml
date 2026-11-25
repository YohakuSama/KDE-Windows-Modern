// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Start

Item {
    id: host
    width: 560
    height: 520
    QQC2.Button { id: anchor; x: 390; y: 80; width: 130; height: 30; onClicked: menu.openAt(anchor) }
    Start.ViewModeMenu { id: menu; parent: host; modes: ["List", "Grid", "Category"]; onModeChosen: mode => currentMode = mode }
    SignalSpy { id: changed; target: menu; signalName: "modeChosen" }
    TestCase {
        name: "StartViewModePopup"
        when: windowShown
        function init() { menu.close(); anchor.y = 80; menu.currentMode = 0; changed.clear(); }
        function test_anchorAndOutsideDismiss() {
            mouseClick(anchor);
            tryCompare(menu, "opened", true);
            compare(menu.x + menu.width, anchor.x + anchor.width);
            compare(menu.y, anchor.y + anchor.height + 4);
            mouseClick(host, 30, 30);
            tryCompare(menu, "opened", false);
            compare(changed.count, 0);
        }
        function test_sameModeAndSelection() {
            menu.openAt(anchor);
            tryCompare(menu, "opened", true);
            const same = menu.contentItem.itemAtIndex(2);
            verify(same !== null);
            mouseClick(same, same.width / 2, same.height / 2);
            tryCompare(menu, "opened", false);
            tryCompare(changed, "count", 1);
            menu.openAt(anchor);
            tryCompare(menu, "opened", true);
            const different = menu.contentItem.itemAtIndex(0);
            verify(different !== null);
            mouseClick(different, different.width / 2, different.height / 2);
            tryCompare(menu, "opened", false);
            tryCompare(menu, "currentMode", 2);
            compare(changed.count, 2);
        }
        function test_bottomEdgeAndEscape() {
            anchor.y = 470;
            menu.openAt(anchor);
            tryCompare(menu, "opened", true);
            compare(menu.y + menu.height, anchor.y - 4);
            keyClick(Qt.Key_Escape);
            tryCompare(menu, "opened", false);
            compare(changed.count, 0);
        }
    }
}
