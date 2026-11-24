// SPDX-License-Identifier: GPL-3.0-or-later
// WinUI: 16px input region, 2px panning indicator, 6px expanded thumb.
// Keep Qt's attached scrollbar geometry and drag behavior.
// https://learn.microsoft.com/windows/apps/develop/ui/controls/scroll-controls
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.ScrollBar {
    id: bar
    policy: QQC2.ScrollBar.AsNeeded
    width: 16
    padding: 0
    hoverEnabled: true
    stepSize: Math.max(0.01, size * 0.9)
    minimumSize: height > 0 ? Math.min(1, 32 / height) : 0
    readonly property int thumbWidth: pointer.hovered || pressed ? 6 : 2
    // Keep the input gutter available without painting an idle thumb.
    readonly property bool indicatorVisible: size < 1 && (pointer.hovered || pressed)

    HoverHandler { id: pointer }

    background: Item {}
    contentItem: Item {
        implicitWidth: 16
        implicitHeight: 32
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: bar.thumbWidth
            radius: width / 2
            color: Kirigami.Theme.textColor
            opacity: bar.indicatorVisible ? (bar.pressed ? 0.72 : 0.55) : 0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
            Behavior on width {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }
}
