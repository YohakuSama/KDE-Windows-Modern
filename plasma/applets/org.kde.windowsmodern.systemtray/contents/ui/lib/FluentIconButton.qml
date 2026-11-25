// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.ToolButton {
    id: control
    Win11Palette { id: fluent }
    implicitWidth: fluent.controlHeight
    implicitHeight: fluent.controlHeight
    icon.width: fluent.menuIconSize
    icon.height: fluent.menuIconSize
    display: PlasmaComponents.AbstractButton.IconOnly
    hoverEnabled: true
    background: Rectangle {
        radius: fluent.controlRadius
        color: !control.enabled ? "transparent"
            : control.down ? fluent.controlPressed
            : control.hovered || control.checked || control.activeFocus ? fluent.controlHover : "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: fluent.accent
    }
}
