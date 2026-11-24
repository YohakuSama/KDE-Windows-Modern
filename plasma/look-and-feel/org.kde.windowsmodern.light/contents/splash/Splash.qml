/* SPDX-License-Identifier: GPL-3.0-or-later */
import QtQuick

Rectangle {
    id: root
    color: "#101010"
    property int stage: 0

    Item {
        anchors.centerIn: parent
        width: 64
        height: 64
        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: 5
                height: 5
                radius: 2.5
                color: "white"
                x: 29.5 + 23 * Math.sin(index * Math.PI / 6)
                y: 29.5 - 23 * Math.cos(index * Math.PI / 6)
                opacity: (index + 1) / 12
            }
        }
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1050
            loops: Animation.Infinite
        }
    }
}
