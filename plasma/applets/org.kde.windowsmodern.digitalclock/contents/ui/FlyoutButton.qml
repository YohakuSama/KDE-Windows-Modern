// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.Button {
    id: control
    property bool quiet: false
    property bool attentionActive: false
    implicitHeight: 28
    padding: 6
    leftPadding: 8
    rightPadding: 8
    icon.width: 14
    icon.height: 14
    font.pixelSize: 12
    background: Rectangle {
        readonly property bool dark: (Kirigami.Theme.backgroundColor.r * 0.299
            + Kirigami.Theme.backgroundColor.g * 0.587 + Kirigami.Theme.backgroundColor.b * 0.114) < 0.5
        radius: 4
        color: control.quiet && !control.hovered && !control.activeFocus ? "transparent"
            : dark ? Qt.rgba(1, 1, 1, control.down ? 0.13
                : control.hovered || control.activeFocus || control.checked || control.attentionActive ? 0.09 : 0.05)
            : Qt.rgba(1, 1, 1, control.down ? 0.35 : control.hovered ? 0.95 : 0.75)
        border.width: control.activeFocus ? 1 : (!dark && !control.quiet ? 1 : 0)
        border.color: control.activeFocus ? Kirigami.Theme.highlightColor
            : Qt.rgba(0, 0, 0, 0.08)
    }
}
