// SPDX-License-Identifier: GPL-3.0-or-later
// Prefer the original Windows 11 26H2 SysBatt Fluent font when it has been
// imported locally. Keep the verified Windows Segoe glyphs as a fallback.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami
import "../js/funcs.js" as Funcs

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool pluggedIn: false
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor

    readonly property string sysBattFontPath: String(StandardPaths.locate(
        StandardPaths.GenericDataLocation,
        "windows-modern/native-assets/shell/fonts/Sysbatt.ttf",
        StandardPaths.LocateFile))
    readonly property bool hasSysBattFont: sysBattFont.status === FontLoader.Ready
    readonly property string visualState: Funcs.batteryVisualState(percent, charging, saver)
    readonly property string iconName: visualState === "unknown" ? "battery-unknown-symbolic"
        : Funcs.batteryIconName(percent, charging, saver)
    readonly property int level: percent < 0 ? 0 : Math.max(0, Math.min(10, Math.round(percent / 10)))
    readonly property int outlineCode: saver ? 0xF849
        : pluggedIn && !charging ? 0xF8E4
        : charging ? 0xF8DB : 0xF8D0
    readonly property int fillCode: {
        if (level <= 0) return 0;
        if (saver && level >= 3) return 0xF84A + level - 3;
        if (charging && level >= 3) return 0xF8DC + level - 3;
        if (pluggedIn && level >= 3) return 0xF8E5 + level - 3;
        return 0xF8D0 + level;
    }
    readonly property color fillColor: charging || pluggedIn ? "#4CD964"
        : percent >= 0 && percent <= 5 ? "#FF4545"
        : percent >= 0 && percent <= 20 ? "#FF9F1A"
        : saver ? "#FFD60A" : foreground

    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize

    FontLoader {
        id: sysBattFont
        source: root.sysBattFontPath
    }

    Item {
        id: sysBattArtwork
        objectName: "wmBatterySysBattArtwork"
        anchors.fill: parent
        visible: root.hasSysBattFont

        Text {
            objectName: "wmBatterySysBattOutline"
            anchors.fill: parent
            text: String.fromCharCode(root.outlineCode)
            font.family: sysBattFont.name
            font.pixelSize: root.glyphSize
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.foreground
            renderType: Text.QtRendering
        }

        Text {
            objectName: "wmBatterySysBattFill"
            anchors.fill: parent
            text: root.fillCode > 0 ? String.fromCharCode(root.fillCode) : ""
            font.family: sysBattFont.name
            font.pixelSize: root.glyphSize
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: root.fillColor
            renderType: Text.QtRendering
        }
    }

    NativeGlyph {
        objectName: "wmBatteryNativeGlyph"
        anchors.centerIn: parent
        width: Math.min(root.width, root.height * 1.25)
        height: Math.min(root.height, root.glyphSize)
        roleName: root.iconName
        foreground: root.foreground
        visible: !root.hasSysBattFont
    }
}
