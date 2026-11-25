// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.Button {
    id: control

    Win11Palette { id: fluent }
    property bool quiet: false
    property bool attentionActive: false
    implicitHeight: Math.max(28, implicitContentHeight + topPadding + bottomPadding)
    padding: 6
    leftPadding: 8
    rightPadding: 8
    icon.width: 14
    icon.height: 14
    font: Kirigami.Theme.defaultFont
    background: Rectangle {
        radius: fluent.controlRadius
        color: control.down ? fluent.controlPressed
            : control.hovered || control.activeFocus || control.checked || control.attentionActive ? fluent.controlHover
            : control.quiet ? "transparent" : fluent.controlFill
        border.width: control.activeFocus ? 1 : 0
        border.color: Kirigami.Theme.highlightColor
    }
}
