// SPDX-License-Identifier: GPL-3.0-or-later
// Modern battery compatibility drawing. Real backend level and state drive
// the coloured fill. The legacy Segoe font remains available for other icons.
import QtQuick
import org.kde.kirigami as Kirigami
import "../js/funcs.js" as Funcs

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor
    readonly property string visualState: Funcs.batteryVisualState(percent, charging, saver)
    readonly property real fillFraction: Funcs.batteryFillFraction(percent)
    readonly property color fillColor: visualState === "charging" ? "#62B85A"
        : visualState === "critical" ? "#E74856"
        : visualState === "saver" ? "#E5A93D" : foreground

    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize

    Item {
        id: shape
        anchors.centerIn: parent
        width: Math.min(root.width, root.height * 1.25)
        height: width * 0.55
        Rectangle {
            id: body
            objectName: "wmBatteryOutline"
            width: shape.width * 0.91
            height: shape.height
            radius: height * 0.30
            color: "transparent"
            border.width: Math.max(1, Math.round(root.glyphSize / 16))
            border.color: root.foreground
            Rectangle {
                id: level
                objectName: "wmBatteryLevelFill"
                readonly property real inset: Math.max(2, Math.round(root.glyphSize / 8))
                x: inset
                y: inset
                width: Math.max(0, body.width - 2 * inset) * root.fillFraction
                height: Math.max(0, body.height - 2 * inset)
                radius: Math.min(height * 0.2, width / 2)
                color: root.fillColor
                visible: root.visualState !== "unknown" && width > 0
            }
        }
        Rectangle {
            anchors.left: body.right
            anchors.verticalCenter: body.verticalCenter
            width: Math.max(1, shape.width - body.width)
            height: body.height * 0.36
            radius: width / 2
            color: root.foreground
        }
        Canvas {
            id: mark
            objectName: "wmBatteryStateMark"
            anchors.horizontalCenter: body.horizontalCenter
            anchors.verticalCenter: body.verticalCenter
            anchors.verticalCenterOffset: root.visualState === "charging" ? -shape.height * 0.22 : 0
            width: shape.width * 0.39
            height: shape.height * 1.22
            visible: root.visualState === "charging" || root.visualState === "unknown"
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: root
                function onVisualStateChanged() { mark.requestPaint(); }
                function onForegroundChanged() { mark.requestPaint(); }
                function onFillColorChanged() { mark.requestPaint(); }
            }
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.clearRect(0, 0, width, height);
                c.lineJoin = "round";
                c.lineCap = "round";
                c.lineWidth = Math.max(1, root.glyphSize / 16);
                if (root.visualState === "unknown") {
                    c.strokeStyle = root.foreground;
                    c.beginPath();
                    c.moveTo(width * 0.2, height * 0.32);
                    c.lineTo(width * 0.8, height * 0.68);
                    c.moveTo(width * 0.8, height * 0.32);
                    c.lineTo(width * 0.2, height * 0.68);
                    c.stroke();
                } else if (root.visualState === "charging") {
                    c.beginPath();
                    c.moveTo(width * 0.60, height * 0.06);
                    c.lineTo(width * 0.12, height * 0.55);
                    c.lineTo(width * 0.45, height * 0.55);
                    c.lineTo(width * 0.32, height * 0.94);
                    c.lineTo(width * 0.90, height * 0.39);
                    c.lineTo(width * 0.58, height * 0.39);
                    c.closePath();
                    c.strokeStyle = Qt.darker(root.fillColor, 1.6);
                    c.fillStyle = root.foreground;
                    c.stroke();
                    c.fill();
                }
            }
        }
    }
}
