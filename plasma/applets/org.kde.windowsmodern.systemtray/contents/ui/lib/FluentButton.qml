// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.Button {
    id: control
    property bool primary: false
    Win11Palette { id: fluent }

    font: Kirigami.Theme.defaultFont
    leftPadding: 12
    rightPadding: 12
    topPadding: 6
    bottomPadding: 6
    implicitHeight: Math.max(fluent.controlHeight, implicitContentHeight + topPadding + bottomPadding)
    implicitWidth: Math.max(80, implicitContentWidth + leftPadding + rightPadding)
    hoverEnabled: true
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.primary ? fluent.accentText : fluent.text
        opacity: control.enabled ? 1 : 0.42
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: fluent.controlRadius
        color: control.primary
            ? (control.down ? Qt.tint(fluent.accent, Qt.rgba(fluent.accentText.r, fluent.accentText.g, fluent.accentText.b, 0.12))
                : control.hovered ? Qt.tint(fluent.accent, Qt.rgba(fluent.accentText.r, fluent.accentText.g, fluent.accentText.b, 0.06)) : fluent.accent)
            : control.down ? fluent.controlPressed : control.hovered ? fluent.controlHover : fluent.controlFill
        opacity: control.enabled ? 1 : 0.5
        border.width: 1
        border.color: control.activeFocus ? (control.primary ? fluent.accentText : fluent.accent)
            : control.primary ? "transparent" : fluent.controlBorder
    }
}
