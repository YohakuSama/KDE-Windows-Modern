/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.login as PlasmaLogin
import "controlMetrics.js" as ControlMetrics

ListView {
    id: root

    property bool uiVisible: false
    property real maximumHeight: contentHeight

    width: 180
    height: Math.min(contentHeight, maximumHeight)
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    visible: count > 1 && uiVisible && PlasmaLogin.GreeterState.loginState !== PlasmaLogin.GreeterState.LoginState.UserPrompt

    delegate: Item {
        id: accountRow
        width: root.width
        height: WinStyle.userSwitcherItemHeight

        Rectangle {
            anchors.fill: parent
            radius: ControlMetrics.controlCornerRadius
            color: accountRow.ListView.isCurrentItem ? "#20FFFFFF"
                : pointer.containsMouse ? "#16FFFFFF" : "transparent"
        }

        Row {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 10

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
                font.weight: Font.Normal
                color: WinStyle.foregroundColor
                verticalAlignment: Text.AlignVCenter
                height: parent.height
            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
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
