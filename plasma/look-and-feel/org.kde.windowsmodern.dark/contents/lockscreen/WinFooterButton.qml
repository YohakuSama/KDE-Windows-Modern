// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts

StatusIconButton {
    id: button
    property alias iconName: button.icon.name
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40
    Layout.alignment: Qt.AlignVCenter
    focusPolicy: Qt.TabFocus
}
