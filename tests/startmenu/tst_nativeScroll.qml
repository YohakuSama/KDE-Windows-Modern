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
        id: testList
        width: 340
        height: 240
        contentWidth: width
        contentHeight: 2400
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        PlasmaComponents3.ScrollBar.vertical: StartScrollBar { id: bar }
        StartWheelHandler {
            view: testList
            rowHeight: 40
        }
    }
    TestCase {
        name: "StartNativeScroll"
        when: windowShown
        function init() {
            testList.cancelFlick();
            testList.contentY = 0;
        }
        function test_scrollbarGeometry() {
            mouseMove(testList, 80, 100);
            tryCompare(bar, "thumbWidth", 2);
            compare(bar.width, 16);
            tryCompare(bar, "indicatorVisible", false);
            mouseMove(bar, bar.width / 2, bar.height / 2);
            tryCompare(bar, "thumbWidth", 6);
            tryCompare(bar, "indicatorVisible", true);
            mouseMove(testList, 80, 100);
            tryCompare(bar, "indicatorVisible", false);
        }
        function test_thinIndicatorWhileBrowsing() {
            mouseMove(testList, 80, 100);
            bar.viewportHovered = true;
            tryCompare(bar, "thumbWidth", 2);
            tryCompare(bar, "indicatorVisible", true);
            bar.viewportHovered = false;
            tryCompare(bar, "indicatorVisible", false);
            bar.scrolling = true;
            tryCompare(bar, "indicatorVisible", true);
            bar.scrolling = false;
            tryCompare(bar, "indicatorVisible", false);
        }
        function test_threeRowsPerNotch() {
            mouseWheel(testList, 80, 100, 0, -120);
            tryVerify(() => testList.contentY >= 110, 1500);
            mouseWheel(testList, 80, 100, 0, -120);
            tryVerify(() => testList.contentY >= 230, 1500);
        }
        function test_dragToBottom() {
            tryVerify(() => bar.contentItem.height > 0);
            const start = bar.contentItem.y + bar.contentItem.height / 2;
            const end = bar.height - bar.contentItem.height / 2 - bar.bottomPadding;
            mouseDrag(bar, bar.width / 2, start, 0, end - start, Qt.LeftButton);
            tryVerify(() => testList.contentY > 0.9 * (testList.contentHeight - testList.height), 1500);
        }
    }
}
