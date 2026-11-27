// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import Qt5Compat.GraphicalEffects

// Shared personal/default avatar presentation for the greeter and lock screen.
Item {
    id: avatar
    property url source
    property int size: 160
    implicitWidth: size
    implicitHeight: size

    Image {
        id: personal
        anchors.fill: parent
        source: String(avatar.source).endsWith("/faces/.face.icon") ? "" : avatar.source
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: personal.width
                height: personal.height
                radius: Math.min(width, height) / 2
            }
        }
    }
    DefaultAccountPortrait {
        anchors.fill: parent
        visible: !personal.visible
        compact: avatar.size <= 48
    }
}
