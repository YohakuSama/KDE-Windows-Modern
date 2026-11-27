/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2022 Aleix Pol Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.components as WorkspaceComponents

StatusIconButton {
    focusPolicy: Qt.TabFocus
    Accessible.description: i18ndc("plasma_login", "Button to change keyboard layout", "Switch layout")
    icon.name: "input-keyboard"

    WorkspaceComponents.KeyboardLayoutSwitcher {
        id: keyboardLayoutSwitcher

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
    }

    text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Switch keyboard layout")
    onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()

    visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
}
