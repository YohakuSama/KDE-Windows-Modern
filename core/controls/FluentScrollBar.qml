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
    // WinUI 21h1_themeresources.xbf: ScrollBarVerticalThumbMinHeight = 30.
    minimumSize: height > 0 ? Math.min(1, 30 / height) : 0
    readonly property int thumbWidth: pointer.hovered || pressed ? 6 : 2
    property bool viewportHovered: false
    property bool scrolling: false
    // Consumers supply their existing theme-mode detection; use the
    // public WinUI ControlStrongFill role rather than dimming text ink.
    property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color thumbBrush: Qt.color(dark
        ? (enabled ? "#8BFFFFFF" : "#3FFFFFFF")
        : (enabled ? "#72000000" : "#51000000"))
    // The thin panning indicator appears while browsing or scrolling.
    // Only entering the edge's input region expands the thumb.
    readonly property bool indicatorVisible: size < 1 && (pointer.hovered || pressed || scrolling || viewportHovered)

    HoverHandler { id: pointer }

    background: Item {}
    contentItem: Item {
        implicitWidth: 16
        implicitHeight: 30
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: bar.thumbWidth
            radius: width / 2
            objectName: "wmFluentScrollThumb"
            color: bar.thumbBrush
            opacity: bar.indicatorVisible ? 1 : 0
            // WinUI 21h1_themeresources.xbf: ScrollBarOpacityChangeDuration (83ms)
            // and ScrollBarExpandDuration (167ms).
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration > 0 ? 83 : 0 }
            }
            Behavior on width {
                NumberAnimation { duration: Kirigami.Units.shortDuration > 0 ? 167 : 0 }
            }
        }
    }
}
