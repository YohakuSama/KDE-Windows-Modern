/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

PlasmaComponents3.ToolButton {
    id: root

    property alias iconName: root.icon.name

    icon.width: 16
    icon.height: 16
    icon.color: WinStyle.foregroundColor
    background: Rectangle {
        radius: 4
        color: root.down ? "#0DFFFFFF" : root.hovered || root.activeFocus ? "#17FFFFFF" : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: WinStyle.accentColor
    }
    display: QQC2.AbstractButton.IconOnly
    flat: true
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

}
