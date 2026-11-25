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
    actionItems: [ Item { visible: false } ]

    Component.onCompleted: {
        if (userList) {
            userList.visible = false;
            userList.opacity = 0;
            userList.height = 0;
        }
        loginButton.forceActiveFocus();
    }

    AccountAvatar {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 140
        Layout.preferredHeight: 140
        Layout.bottomMargin: 16
        source: screen.userListModel && screen.userListModel.count > 0
            ? screen.userListModel.get(0).icon : ""
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 4
        text: {
            if (!screen.userListModel || screen.userListModel.count === 0) return "";
            const user = screen.userListModel.get(0);
            return user.realName || user.name || "";
        }
        color: "white"
        font.pixelSize: 32
        horizontalAlignment: Text.AlignHCenter
    }

    PlasmaComponents3.Button {
        id: loginButton
        focus: true
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in")
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 144
        Layout.preferredHeight: 42
        background: Rectangle {
            radius: 4
            color: loginButton.down ? "#26FFFFFF" : loginButton.hovered ? "#33FFFFFF" : "#20FFFFFF"
            border.width: loginButton.activeFocus ? 2 : 1
            border.color: loginButton.activeFocus ? "#FFFFFF" : "#88FFFFFF"
        }
        contentItem: Text {
            text: loginButton.text
            color: "white"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: Qt.quit();
        Keys.onEnterPressed: clicked()
        Keys.onReturnPressed: clicked()
    }
}
