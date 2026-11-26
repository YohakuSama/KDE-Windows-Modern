// SPDX-License-Identifier: GPL-3.0-or-later
// Original Windows shell outline and fill artwork share the same canvas.
import QtQuick
import QtCore
import org.kde.kirigami as Kirigami
import "batteryState.js" as BatteryState

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool pluggedIn: charging
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor
    readonly property bool known: Number.isFinite(percent) && percent >= 0
    readonly property string visualState: BatteryState.batteryVisualState(percent, charging, saver)
    // Keep the real plugged-in state even when charging has completed or
    // the battery backend cannot report its level.
    readonly property string iconName: BatteryState.batteryIconName(percent, charging || pluggedIn, saver)
    readonly property int level: known ? (percent <= 5 ? 0 : Math.min(10, Math.round(percent / 10))) : 0
    readonly property string shellState: charging ? "charging" : pluggedIn ? "plugged" : saver ? "saver" : "normal"
    readonly property int outlineCode: shellState === "charging" ? 0xf8db
        : shellState === "plugged" ? 0xf8e4 : shellState === "saver" ? 0xf849 : 0xf8d0
    readonly property int fillCode: level === 0 ? 0
        : shellState === "normal" ? 0xf8d0 + level
        : level < 3 ? 0
        : shellState === "charging" ? 0xf8dc + level - 3
        : shellState === "plugged" ? 0xf8e5 + level - 3 : 0xf84a + level - 3
    readonly property string outlineSource: shellSource(outlineCode)
    readonly property string fillSource: fillCode ? shellSource(fillCode) : ""
    readonly property bool modernAvailable: known && outlineSource.length > 0 && (!fillCode || fillSource.length > 0)
    readonly property bool darkSurface: Kirigami.ColorUtils.brightnessForColor(foreground) === Kirigami.ColorUtils.Light
    readonly property color fillColor: charging || pluggedIn ? (darkSurface ? "#9fd89f" : "#107c10")
        : percent <= 10 ? (darkSurface ? "#d92c2c" : "#c50f1f")
        : saver ? "#eaa300" : foreground

    function shellSource(code) {
        return String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/shell-assets/battery/" + code.toString(16) + ".svg", StandardPaths.LocateFile));
    }

    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize
    // Preserve the imported font's canvas aspect ratio in every layer.
    readonly property real canvasWidth: Math.max(0, Math.min(width, height * 1.25, glyphSize * 1.25))
    readonly property real canvasHeight: canvasWidth / 1.25
    // Previous genuine Windows 11 import is used only when the new
    // shell artwork is unavailable. Never resolve an arbitrary theme icon.
    NativeGlyph {
        objectName: "wmBatteryNativeGlyph"
        anchors.centerIn: parent
        width: root.canvasWidth
        height: root.canvasHeight
        roleName: root.iconName
        foreground: root.foreground
        opacity: root.modernAvailable ? 0 : 1
    }
    Kirigami.Icon {
        objectName: "wmBatteryShellOutline"
        anchors.centerIn: parent
        width: root.canvasWidth
        height: root.canvasHeight
        source: root.outlineSource
        fallback: ""
        visible: root.modernAvailable
        isMask: true
        color: root.foreground
        roundToIconSize: false
        animated: false
    }
    Kirigami.Icon {
        objectName: "wmBatteryShellFill"
        anchors.centerIn: parent
        width: root.canvasWidth
        height: root.canvasHeight
        source: root.fillSource
        fallback: ""
        visible: root.modernAvailable && root.fillCode !== 0
        isMask: true
        color: root.fillColor
        roundToIconSize: false
        animated: false
    }
}
