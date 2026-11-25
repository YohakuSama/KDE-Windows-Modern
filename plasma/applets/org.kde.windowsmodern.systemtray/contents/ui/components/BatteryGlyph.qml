// SPDX-License-Identifier: GPL-3.0-or-later
// Original imported Windows battery states. The newer 26H2 SysBatt
// source is not yet identified; never draw a replacement or use Breeze.
import QtQuick
import org.kde.kirigami as Kirigami
import "../js/funcs.js" as Funcs

Item {
    id: root
    property real glyphSize: 18
    property real percent: -1
    property bool charging: false
    property bool saver: false
    property color foreground: Kirigami.Theme.textColor
    readonly property string visualState: Funcs.batteryVisualState(percent, charging, saver)
    readonly property string iconName: visualState === "unknown" ? "battery-unknown-symbolic"
        : Funcs.batteryIconName(percent, charging, saver)
    implicitWidth: Math.ceil(glyphSize * 1.25)
    implicitHeight: glyphSize
    NativeGlyph {
        objectName: "wmBatteryNativeGlyph"
        anchors.centerIn: parent
        width: Math.min(root.width, root.height * 1.25)
        height: Math.min(root.height, root.glyphSize)
        roleName: root.iconName
        foreground: root.foreground
    }
}
