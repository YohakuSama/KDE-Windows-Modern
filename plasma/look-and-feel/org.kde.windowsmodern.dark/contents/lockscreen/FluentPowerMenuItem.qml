// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Explicit menu items must use this type: Menu.delegate only styles
// dynamically generated items, not explicitly declared MenuItems.
QQC2.MenuItem {
    id: control
    implicitHeight: Math.max(36, contentItem.implicitHeight + 12)
    property bool actionAvailable: true
    visible: actionAvailable
    enabled: actionAvailable
    height: actionAvailable ? implicitHeight : 0
    leftPadding: 8
    rightPadding: 8
    topPadding: 6
    bottomPadding: 6
    font: Kirigami.Theme.defaultFont

    contentItem: RowLayout {
        spacing: 8
        Kirigami.Icon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            source: control.icon.name
            color: "#FFFFFF"
            isMask: true
            roundToIconSize: false
            opacity: control.enabled ? 1 : 0.4
        }
        Text {
            Layout.fillWidth: true
            text: control.text
            font: control.font
            color: control.enabled ? "#FFFFFF" : "#A0A0A0"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
    background: Rectangle {
        radius: 4
        color: control.down ? "#26FFFFFF" : control.highlighted || control.hovered ? "#20FFFFFF" : "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: "#FFFFFF"
    }
}
