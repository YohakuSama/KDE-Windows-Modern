// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.plasma.components as PlasmaComponents3
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components"

Item {
    width: 360
    height: 260
    Flickable {
        id: view
        width: 340
        height: 240
        contentWidth: width
        contentHeight: 2400
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        PlasmaComponents3.ScrollBar.vertical: StartScrollBar { id: bar }
        StartWheelHandler {
            view: view
            rowHeight: 40
        }
    }
    TestCase {
        name: "StartNativeScroll"
        when: windowShown
        function init() {
            view.cancelFlick();
            view.contentY = 0;
        }
        function test_threeRowsPerNotch() {
            mouseWheel(view, 80, 100, 0, -120);
            tryVerify(() => view.contentY >= 110, 1500);
            mouseWheel(view, 80, 100, 0, -120);
            tryVerify(() => view.contentY >= 230, 1500);
        }
        function test_dragToBottom() {
            tryVerify(() => bar.contentItem.height > 0);
            const start = bar.contentItem.y + bar.contentItem.height / 2;
            const end = bar.height - bar.contentItem.height / 2 - bar.bottomPadding;
            mouseDrag(bar, bar.width / 2, start, 0, end - start, Qt.LeftButton);
            tryVerify(() => view.contentY > 0.9 * (view.contentHeight - view.height), 1500);
        }
    }
}
