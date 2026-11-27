// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts

StatusIconButton {
    id: button
    property alias iconName: button.icon.name
    Layout.preferredWidth: 32
    Layout.preferredHeight: 32
    Layout.alignment: Qt.AlignVCenter
    focusPolicy: Qt.TabFocus
}
