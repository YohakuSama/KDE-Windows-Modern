// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

// The visible track is 4px, but the input control must have its own
// nonzero implicit size. A drawn handle with only explicit dimensions
// otherwise leaves Plasma's implicit slider height at zero.
T.Slider {
    id: control
    implicitWidth: 120
    implicitHeight: 32
    padding: 0
    orientation: Qt.Horizontal
    live: true
    snapMode: T.Slider.SnapAlways
    hoverEnabled: true
    wheelEnabled: true
    opacity: enabled ? 1 : 0.5

    Win11Palette { id: fluent }

    background: Item {
        implicitWidth: 120
        implicitHeight: 4
        x: control.leftPadding + control.handle.width / 2
        y: (control.height - height) / 2
        width: Math.max(0, control.availableWidth - control.handle.width)
        height: implicitHeight
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(fluent.text.r, fluent.text.g, fluent.text.b, 0.38)
        }
        Rectangle {
            width: parent.width * control.position
            height: parent.height
            x: control.mirrored ? parent.width - width : 0
            radius: height / 2
            color: fluent.accent
        }
    }

    handle: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        width: implicitWidth
        height: implicitHeight
        x: control.leftPadding + control.visualPosition * Math.max(0, control.availableWidth - width)
        y: (control.height - height) / 2
        radius: width / 2
        color: fluent.menuBackground
        border.width: 1
        border.color: control.visualFocus ? fluent.accent : fluent.controlBorder
        Rectangle {
            anchors.centerIn: parent
            width: control.pressed ? 10 : 12
            height: width
            radius: width / 2
            color: fluent.accent
        }
    }
}
