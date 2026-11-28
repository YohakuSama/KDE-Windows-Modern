// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "lockMetrics.js" as LockMetrics

// Shared personal/default avatar presentation for the greeter and lock screen.
Item {
    id: avatar
    property url source
    property int size: LockMetrics.accountAvatarMaximum
    implicitWidth: size
    implicitHeight: size

    Image {
        id: personal
        anchors.fill: parent
        source: String(avatar.source).endsWith("/faces/.face.icon") ? "" : avatar.source
        sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)),
                            Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
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
