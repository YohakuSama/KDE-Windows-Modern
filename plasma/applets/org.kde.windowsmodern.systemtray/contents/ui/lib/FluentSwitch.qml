// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../js/colorType.js" as ColorType

QQC2.Switch {
    id: control
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    property color shellAccent: Kirigami.Theme.highlightColor
    readonly property color accent: ColorType.accentForSurface(shellAccent,
        Qt.color(ColorType.cardFill(dark, false)))
    implicitWidth: 44
    implicitHeight: 32
    padding: 0
    hoverEnabled: true
    background: Rectangle {
        radius: 4
        color: "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: control.accent
    }
    contentItem: Item {}
    indicator: Rectangle {
        objectName: "wmDetailSwitchTrack"
        readonly property color fg: Kirigami.Theme.textColor
        x: (control.width - width) / 2
        y: (control.height - height) / 2
        width: 40
        height: 20
        radius: 10
        color: control.checked
            ? Qt.tint(control.accent, Qt.rgba(fg.r, fg.g, fg.b, control.down ? 0.12 : control.hovered ? 0.06 : 0))
            : ColorType.rowFill(control.dark, false, control.hovered, control.down)
        border.width: control.checked ? 0 : 1
        border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.65)
        opacity: control.enabled ? 1 : 0.45
        Rectangle {
            width: control.down ? 10 : 12
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: (control.checked !== control.mirrored) ? parent.width - width - 4 : 4
            color: control.checked ? ColorType.contrastingForeground(control.accent) : Kirigami.Theme.textColor
            Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutQuad } }
        }
    }
}
