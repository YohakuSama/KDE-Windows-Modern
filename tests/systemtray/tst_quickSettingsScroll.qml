// SPDX-License-Identifier: GPL-3.0-or-later
// Exercise actual Qt mouse events, not a standalone thumb formula.
import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import org.kde.kirigami as Kirigami
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib"

Item {
    id: root
    width: 360
    height: 240
    Flickable {
        id: view
        width: 300
        height: 220
        contentWidth: width
        contentHeight: 880
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Rectangle {
            width: view.width
            height: view.contentHeight
            color: "transparent"
        }
        QQC2.ScrollBar.vertical: FluentScrollBar {
            id: bar
            policy: QQC2.ScrollBar.AlwaysOn
        }
        Kirigami.WheelHandler {
            target: view
            filterMouseEvents: true
            verticalStepSize: 120
        }
    }
    Flickable {
        id: gridWithoutRail
        x: 0
        width: 300
        height: 220
        contentWidth: width
        contentHeight: 440
        visible: false
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Kirigami.WheelHandler {
            target: gridWithoutRail
            filterMouseEvents: true
            blockTargetWheel: true
            verticalStepSize: 80
        }
    }
    TestCase {
        name: "NativeQuickSettingsScroll"
        when: windowShown
        function init() {
            view.cancelFlick();
            view.contentY = 0;
        }
        function test_scrollbarGeometry() {
            mouseMove(view, 100, 100);
            tryCompare(bar, "thumbWidth", 2);
            compare(bar.width, 16);
            tryCompare(bar, "indicatorVisible", false);
            mouseMove(bar, bar.width / 2, bar.height / 2);
            tryCompare(bar, "thumbWidth", 6);
            tryCompare(bar, "indicatorVisible", true);
            mouseMove(view, 80, 100);
            tryCompare(bar, "indicatorVisible", false);
        }
        function test_gridWithoutRailStillScrolls() {
            view.visible = false;
            gridWithoutRail.visible = true;
            gridWithoutRail.contentY = 0;
            mouseWheel(gridWithoutRail, 100, 100, 0, -120);
            tryVerify(() => gridWithoutRail.contentY >= 70, 1500);
            mouseWheel(gridWithoutRail, 100, 100, 0, -360);
            tryCompare(gridWithoutRail, "contentY", 220, 1500);
            gridWithoutRail.visible = false;
            view.visible = true;
        }
        function cleanup() {
            gridWithoutRail.visible = false;
            view.visible = true;
        }
        function test_wheelMovesImmediatelyToNextRow() {
            mouseWheel(view, 100, 100, 0, -120);
            tryVerify(() => view.contentY >= 110, 1500);
            mouseWheel(view, 100, 100, 0, -240);
            tryVerify(() => view.contentY >= 345, 1500);
        }
        function test_dragThumbToEnd() {
            tryVerify(() => bar.contentItem.height > 0);
            const start = bar.contentItem.y + bar.contentItem.height / 2;
            const end = bar.height - bar.contentItem.height / 2 - bar.bottomPadding;
            mouseDrag(bar, bar.width / 2, start, 0, end - start, Qt.LeftButton);
            tryVerify(() => view.contentY > 0.9 * (view.contentHeight - view.height), 1500);
        }
    }
}
