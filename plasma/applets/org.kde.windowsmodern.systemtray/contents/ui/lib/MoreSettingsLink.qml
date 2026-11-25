// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

PlasmaComponents3.ToolButton {
    id: root
    property string kcm
    implicitHeight: 38
    implicitWidth: 200
    contentItem: PlasmaComponents3.Label {
        text: root.text
        color: Kirigami.Theme.textColor
        font.pixelSize: 12
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        leftPadding: 16
        rightPadding: 12
        elide: Text.ElideRight
    }
    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, root.down ? 0.10 : root.hovered || root.activeFocus ? 0.06 : 0)
        }
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.09)
        }
    }
}
