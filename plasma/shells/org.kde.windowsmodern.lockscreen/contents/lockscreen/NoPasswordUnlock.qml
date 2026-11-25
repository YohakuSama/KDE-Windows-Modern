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
    readonly property int avatarSize: Math.max(1, Math.floor(Math.min(160, width * 0.6, height * 0.32)))
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
        size: screen.avatarSize
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        Layout.bottomMargin: 16
        source: screen.userListModel && screen.userListModel.count > 0
            ? screen.userListModel.get(0).icon : ""
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: screen.width
        Layout.bottomMargin: 4
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: {
            if (!screen.userListModel || screen.userListModel.count === 0) return "";
            const user = screen.userListModel.get(0);
            return user.realName || user.name || "";
        }
        color: "white"
        font.pixelSize: 28
        horizontalAlignment: Text.AlignHCenter
    }

    PlasmaComponents3.Button {
        id: loginButton
        focus: true
        text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in")
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.min(144, screen.width)
        Layout.preferredHeight: 42
        background: Rectangle {
            radius: 6
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
