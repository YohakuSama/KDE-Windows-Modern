/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls 2.15 as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.login as PlasmaLogin
import "lockMetrics.js" as LockMetrics

QQC2.Menu {
    id: root

    width: WinStyle.powerMenuWidth
    padding: LockMetrics.powerMenuPadding

    background: Rectangle {
        color: WinStyle.menuBackground
        border.color: WinStyle.menuBorder
        border.width: 1
        radius: LockMetrics.menuRadius
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sleep")
        icon.name: "system-suspend"
        onTriggered: PlasmaLogin.SessionManagement.suspend()
        actionAvailable: PlasmaLogin.SessionManagement.canSuspend
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Shut down")
        icon.name: "system-shutdown"
        onTriggered: PlasmaLogin.SessionManagement.requestShutdown(PlasmaLogin.SessionManagement.ConfirmationMode.Skip)
        actionAvailable: PlasmaLogin.SessionManagement.canShutdown
    }

    FluentPowerMenuItem {
        width: root.availableWidth
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Restart")
        icon.name: "system-reboot"
        onTriggered: PlasmaLogin.SessionManagement.requestReboot(PlasmaLogin.SessionManagement.ConfirmationMode.Skip)
        actionAvailable: PlasmaLogin.SessionManagement.canReboot
    }
}
