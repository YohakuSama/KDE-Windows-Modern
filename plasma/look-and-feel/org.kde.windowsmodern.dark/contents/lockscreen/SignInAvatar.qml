// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: avatar
    property url source
    property int size: 192
    readonly property bool hasPersonalImage: personal.status === Image.Ready
    implicitWidth: size
    implicitHeight: size

    // Do not treat the bundled placeholder as a custom account photo.
    readonly property string requestedSource: String(source)
    readonly property bool usePersonalSource: requestedSource.length > 0
        && !/(?:\/|^)faces\/\.face\.icon$/i.test(requestedSource)

    Rectangle {
        objectName: "wmAvatarCircle"
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: "#14FFFFFF"
        visible: !avatar.hasPersonalImage

        Image {
            objectName: "wmAvatarGlyph"
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.65)
            height: width
            source: Qt.resolvedUrl("account-person.svg")
            fillMode: Image.PreserveAspectFit
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
        }
    }

    Image {
        id: personal
        anchors.fill: parent
        source: avatar.usePersonalSource ? avatar.source : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: avatar.hasPersonalImage
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: personal.width
                height: personal.height
                radius: Math.min(width, height) / 2
            }
        }
    }
}
