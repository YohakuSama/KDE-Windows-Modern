// SPDX-License-Identifier: GPL-3.0-or-later
// Render the original Microsoft Segoe Fluent Icons artwork installed by
// the local native asset importer. This is the legacy glyph family, not
// the newer SysBatt Fluent Icons battery. Never invent replacement paths.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami
import "../js/funcs.js" as Funcs

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor
    readonly property string iconName: Funcs.batteryIconName(percent, charging, saver)
    readonly property url installedAsset: StandardPaths.locate(StandardPaths.GenericDataLocation,
        "icons/windows-modern/status/" + iconName + ".svg", StandardPaths.LocateFile)

    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize

    Kirigami.Icon {
        objectName: "wmBatterySourceIcon"
        anchors.centerIn: parent
        // The original asset has a square em box. Its horizontal artwork
        // fits the wider battery cell; don't stretch its native aspect ratio.
        width: Math.max(1, Math.min(root.width, Math.ceil(root.height * 1.25)))
        height: width
        roundToIconSize: false
        isMask: true
        color: root.foreground
        source: String(root.installedAsset).length > 0 ? root.installedAsset : root.iconName
    }
}
