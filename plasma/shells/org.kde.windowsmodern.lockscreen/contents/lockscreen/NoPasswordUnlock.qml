/*
    SPDX-FileCopyrightText: 2022 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2025 Windows Modern Theme

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3

import org.kde.breeze.components

SessionManagementScreen {
    id: screen
    focus: true
    showUserList: true

    Component.onCompleted: {
        if (userList) {
            userList.visible = false;
            userList.opacity = 0;
            userList.height = 0;
        }
        forceActiveFocus();
    }

    AccountAvatar {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 140
        Layout.preferredHeight: 140
        source: screen.userListModel && screen.userListModel.count > 0
            ? screen.userListModel.get(0).icon : ""
    }

    PlasmaComponents3.Button {
        id: loginButton
        focus: true
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in")
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 144
        Layout.preferredHeight: 42
        onClicked: Qt.quit();
        Keys.onEnterPressed: clicked()
        Keys.onReturnPressed: clicked()
    }
}
