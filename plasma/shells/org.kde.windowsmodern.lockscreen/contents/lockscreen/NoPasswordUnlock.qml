/*
    SPDX-FileCopyrightText: 2022 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2025 Windows Modern Theme

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3

import org.kde.breeze.components
import "SignInMetrics.js" as SignInMetrics

SessionManagementScreen {
    id: screen
    focus: true
    showUserList: true
    actionItems: [ Item { visible: false } ]
    actionItemsVisible: false
    readonly property int avatarSize: SignInMetrics.avatarSize(width, height)

    Component.onCompleted: {
        if (userList) {
            userList.visible = false;
            userList.opacity = 0;
            userList.height = 0;
        }
        forceActiveFocus();
    }

    readonly property Item signInForm: ColumnLayout {
        parent: screen
        width: Math.min(screen.width, 380)
        height: implicitHeight
        anchors.horizontalCenter: screen.horizontalCenter
        y: SignInMetrics.formTop(screen.height, height, screen.avatarSize)
        spacing: 8
        AccountAvatar {
            Layout.alignment: Qt.AlignHCenter
            size: screen.avatarSize
            Layout.bottomMargin: 10
            source: screen.userListModel && screen.userListModel.count > 0
                ? screen.userListModel.get(0).icon : ""
        }

        PlasmaComponents3.Button {
            id: loginButton
            focus: true
            text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button no-password unlock", "Unlock")
            icon.name: "unlock"
            onClicked: Qt.quit();
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()
        }
    }
}
