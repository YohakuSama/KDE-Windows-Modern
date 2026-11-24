// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: avatar
    property url source
    property int size: 140
    implicitWidth: size
    implicitHeight: size

    Image {
        id: personal
        anchors.fill: parent
        source: avatar.source
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
    // The original mapped Windows default icon is copied into the lock
    // package by the installer. Never leave a blank circle on load failure.
    Image {
        anchors.fill: parent
        visible: !personal.visible
        source: Qt.resolvedUrl("default-avatar.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: avatar.width
        sourceSize.height: avatar.height
    }
}
