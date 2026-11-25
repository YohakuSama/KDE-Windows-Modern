/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.login as PlasmaLogin

ListView {
    id: root

    property bool uiVisible: false

    width: 240
    height: contentHeight
    clip: true

    visible: count > 1 && uiVisible && PlasmaLogin.GreeterState.loginState !== PlasmaLogin.GreeterState.LoginState.UserPrompt

    delegate: Item {
        id: userRow
        width: root.width
        height: WinStyle.userSwitcherItemHeight
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: userRow.ListView.isCurrentItem || pointer.hovered ? "#17FFFFFF" : "transparent"
        }

        HoverHandler { id: pointer }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            WinAvatar {
                size: WinStyle.userSwitcherAvatarSize
                source: model.icon || ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: Math.max(0, parent.width - WinStyle.userSwitcherAvatarSize - parent.spacing)
                text: model.realName || model.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: WinStyle.fontFamily
                font.pixelSize: WinStyle.bodyPixelSize
                color: WinStyle.foregroundColor
                verticalAlignment: Text.AlignVCenter
                height: WinStyle.userSwitcherItemHeight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.currentIndex = index;
                PlasmaLogin.GreeterState.userListIndex = index;
            }
        }
    }

    Connections {
        target: PlasmaLogin.GreeterState
        function onUserListIndexChanged() {
            if (root.currentIndex !== PlasmaLogin.GreeterState.userListIndex) {
                root.currentIndex = PlasmaLogin.GreeterState.userListIndex;
            }
        }
    }
}
