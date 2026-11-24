// SPDX-License-Identifier: GPL-3.0-or-later
// Project-drawn colored battery artwork, modeled on the Windows 11
// October 2025 battery UI. All geometry is in logical pixels.
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../js/funcs.js" as Funcs

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor
    property color backgroundColor: Kirigami.Theme.backgroundColor
    readonly property string visualState: Funcs.batteryVisualState(percent, charging, saver)
    readonly property real fillFraction: Funcs.batteryFillFraction(percent)
    readonly property bool dark: (0.2126 * backgroundColor.r + 0.7152 * backgroundColor.g
                                 + 0.0722 * backgroundColor.b) < 0.5
    readonly property color levelColor: {
        switch (visualState) {
        case "charging": return dark ? "#73d88b" : "#218739";
        case "saver": return dark ? "#f9d65c" : "#936800";
        case "critical": return dark ? "#ff6868" : "#c42b1c";
        default: return foreground;
        }
    }
    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize

    Item {
        anchors.centerIn: parent
        width: 20
        height: 16
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center

        Rectangle {
            objectName: "wmBatteryTerminal"
            x: 18
            y: 5
            width: 1.75
            height: 6
            radius: 0.875
            color: root.foreground
        }
        Rectangle {
            objectName: "wmBatteryOutline"
            x: 0.5
            y: 2
            width: 17.5
            height: 12
            radius: 2
            color: "transparent"
            border.color: root.foreground
            border.width: 1
        }
        Rectangle {
            objectName: "wmBatteryLevelFill"
            visible: root.visualState !== "unknown" && width > 0
            x: 2.5
            y: 4
            width: 13.5 * root.fillFraction
            height: 8
            radius: Math.min(1, width / 2)
            color: root.levelColor
        }
        Text {
            anchors.centerIn: parent
            visible: root.visualState === "unknown"
            text: "?"
            color: root.foreground
            font.pixelSize: 8
        }
        Shape {
            anchors.fill: parent
            visible: root.visualState === "charging"
            ShapePath {
                strokeWidth: 0.8
                strokeColor: root.backgroundColor
                fillColor: root.foreground
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 10.6 2.5 L 6.7 8.3 L 9.6 8.3 L 8.8 12.2 L 14 6.5 L 10.9 6.5 Z" }
            }
        }
    }
}
