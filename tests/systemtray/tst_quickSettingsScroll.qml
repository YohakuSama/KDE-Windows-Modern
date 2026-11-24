// SPDX-License-Identifier: GPL-3.0-or-later
// Exercise actual Qt mouse events, not a standalone thumb formula.
import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import org.kde.kirigami as Kirigami

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
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: bar
            width: 24
            policy: QQC2.ScrollBar.AlwaysOn
            stepSize: Math.max(0.01, size * 0.9)
        }
        Kirigami.WheelHandler {
            target: view
            filterMouseEvents: true
            verticalStepSize: 120
        }
    }
    TestCase {
        name: "NativeQuickSettingsScroll"
        when: windowShown
        function init() {
            view.cancelFlick();
            view.contentY = 0;
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
