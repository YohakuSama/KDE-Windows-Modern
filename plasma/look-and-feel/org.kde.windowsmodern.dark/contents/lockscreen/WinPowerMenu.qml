/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.login as PlasmaLogin

QQC2.Menu {
    id: root

    width: Math.max(160, WinStyle.powerMenuWidth)
    padding: 4

    background: Rectangle {
        radius: 8
        color: WinStyle.menuBackground
        border.color: WinStyle.menuBorder
        border.width: 1
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_login", "Sleep")
        icon.name: "system-suspend"
        onTriggered: PlasmaLogin.SessionManagement.suspend()
        actionAvailable: PlasmaLogin.SessionManagement.canSuspend
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_login", "Shut Down")
        icon.name: "system-shutdown"
        onTriggered: PlasmaLogin.SessionManagement.requestShutdown(PlasmaLogin.SessionManagement.ConfirmationMode.Skip)
        actionAvailable: PlasmaLogin.SessionManagement.canShutdown
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_login", "Restart")
        icon.name: "system-reboot"
        onTriggered: PlasmaLogin.SessionManagement.requestReboot(PlasmaLogin.SessionManagement.ConfirmationMode.Skip)
        actionAvailable: PlasmaLogin.SessionManagement.canReboot
    }
}
