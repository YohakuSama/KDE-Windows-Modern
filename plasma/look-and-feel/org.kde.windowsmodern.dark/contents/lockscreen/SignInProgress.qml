// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick

// Five independent dots, from the owner's reference. Scene-graph
// rectangles avoid painting a new Canvas image on every frame.
Item {
    id: control
    property bool running: visible
    property color color: "#FFFFFF"
    property real phase: 0
    readonly property int dotCount: 5
    readonly property real extent: Math.min(width, height)
    implicitWidth: 36
    implicitHeight: 36

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 1600
        loops: Animation.Infinite
        running: control.running && control.visible
    }

    Repeater {
        model: control.dotCount
        Rectangle {
            required property int index
            objectName: "wmLoadingDot" + index
            readonly property real angle: 2 * Math.PI * (control.phase - 0.25) - index * Math.PI / 8
            width: control.extent * 0.086
            height: width
            radius: width / 2
            color: control.color
            antialiasing: true
            x: control.width / 2 + control.extent * 0.36 * Math.cos(angle) - width / 2
            y: control.height / 2 + control.extent * 0.36 * Math.sin(angle) - height / 2
        }
    }
}
