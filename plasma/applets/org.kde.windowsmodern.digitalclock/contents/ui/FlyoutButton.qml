// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.Button {
    id: control
    property bool quiet: false
    property bool attentionActive: false
    focusPolicy: Qt.TabFocus
    implicitHeight: 28
    padding: 6
    leftPadding: 8
    rightPadding: 8
    icon.width: 14
    icon.height: 14
    font.pixelSize: 12
    Win11Palette { id: colors }
    readonly property bool selected: checked || attentionActive
    // Pointer activation must not leave the keyboard focus outline behind.
    readonly property bool keyboardFocus: activeFocus && visualFocus
    icon.color: selected ? colors.accentText : colors.text
    palette.buttonText: selected ? colors.accentText : colors.text
    background: Rectangle {
        radius: 4
        color: control.selected ? colors.accent
            : control.down ? colors.pressed
            : control.hovered || control.keyboardFocus ? colors.hover
            : control.quiet ? "transparent" : colors.surface
        border.width: control.quiet && !control.selected && !control.keyboardFocus ? 0 : 1
        border.color: control.keyboardFocus ? colors.accent : colors.surfaceBorder
        opacity: control.enabled ? 1 : 0.55
    }
}
