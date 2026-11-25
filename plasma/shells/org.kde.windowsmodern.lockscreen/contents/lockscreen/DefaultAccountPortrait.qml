// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick

// Use the Microsoft Fluent Person silhouette for missing account pictures.
// The main sign-in portrait and the compact user list have different surfaces.
Rectangle {
    id: portrait
    objectName: "wmDefaultAccountPortrait"
    property bool compact: false
    radius: Math.min(width, height) / 2
    color: compact ? "#F2F2F2" : "#10FFFFFF"

    Image {
        objectName: "wmDefaultAccountGlyph"
        anchors.centerIn: parent
        width: Math.round(Math.min(parent.width, parent.height) * (portrait.compact ? 0.82 : 0.66))
        height: width
        source: Qt.resolvedUrl(portrait.compact ? "default-avatar-small.svg" : "default-avatar.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: Math.max(1, width)
        sourceSize.height: Math.max(1, height)
    }
}
