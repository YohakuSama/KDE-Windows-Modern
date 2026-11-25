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
    property real maximumHeight: contentHeight

    width: 240
    height: Math.min(contentHeight, maximumHeight)
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    visible: count > 1 && uiVisible && PlasmaLogin.GreeterState.loginState !== PlasmaLogin.GreeterState.LoginState.UserPrompt

    delegate: Item {
        width: root.width
        height: WinStyle.userSwitcherItemHeight
        opacity: ListView.isCurrentItem ? 1.0 : 0.7

        Row {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            WinAvatar {
                id: userAvatar
                size: WinStyle.userSwitcherAvatarSize
                width: size
                height: size
                source: model.icon || ""
            }

            Text {
                width: Math.max(0, parent.width - userAvatar.width - parent.spacing)
                text: model.realName || model.name
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: WinStyle.fontFamily
                font.pixelSize: WinStyle.userSwitcherNamePixelSize
                font.weight: Font.Light
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
