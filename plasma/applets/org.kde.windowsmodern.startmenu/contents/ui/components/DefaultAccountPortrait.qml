// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtCore
import Qt5Compat.GraphicalEffects

// A private original default account picture takes precedence over the
// Fluent Person fallback. Personal pictures are handled by the caller.
Rectangle {
    id: portrait
    objectName: "wmDefaultAccountPortrait"
    property bool compact: false
    property bool showImported: true
    property url fallbackSource: Qt.resolvedUrl(compact ? "default-avatar-small.svg" : "default-avatar.svg")
    readonly property string importedSource: {
        if (!showImported) return "";
        for (const suffix of [".png", ".jpg", ".bmp"]) {
            const path = String(StandardPaths.locate(StandardPaths.GenericDataLocation,
                "windows-modern/shell-assets/account/default" + suffix, StandardPaths.LocateFile));
            if (path.length > 0) return path;
        }
        return "";
    }

    radius: Math.min(width, height) / 2
    color: compact ? "#F2F2F2" : "#10FFFFFF"

    Image {
        id: original
        objectName: "wmImportedDefaultAccount"
        anchors.fill: parent
        source: portrait.importedSource
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: portrait.showImported && status === Image.Ready
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: original.width
                height: original.height
                radius: Math.min(width, height) / 2
            }
        }
    }

    Image {
        objectName: "wmDefaultAccountGlyph"
        anchors.centerIn: parent
        width: Math.round(Math.min(parent.width, parent.height) * (portrait.compact ? 0.82 : 0.66))
        height: width
        source: portrait.fallbackSource
        visible: !portrait.showImported || original.status !== Image.Ready
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: Math.max(1, width)
        sourceSize.height: Math.max(1, height)
    }
}
