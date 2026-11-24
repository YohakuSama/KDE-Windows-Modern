// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.Button {
    id: control
    property bool quiet: false
    property bool highlighted: false
    implicitHeight: 28
    padding: 6
    leftPadding: 8
    rightPadding: 8
    icon.width: 14
    icon.height: 14
    font.pixelSize: 12
    background: Rectangle {
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, control.down ? 0.13
                : control.hovered || control.activeFocus || control.checked || control.highlighted ? 0.09
                : control.quiet ? 0 : 0.05)
        border.width: control.activeFocus ? 1 : 0
        border.color: Kirigami.Theme.highlightColor
    }
}
