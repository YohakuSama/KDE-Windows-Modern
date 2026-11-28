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
    keyNavigationEnabled: true
    activeFocusOnTab: visible

    visible: count > 1 && uiVisible && PlasmaLogin.GreeterState.loginState !== PlasmaLogin.GreeterState.LoginState.UserPrompt

    function activateCurrentUser() {
        if (currentIndex >= 0 && currentIndex < count) {
            PlasmaLogin.GreeterState.userListIndex = currentIndex;
        }
    }

    Keys.onReturnPressed: event => { activateCurrentUser(); event.accepted = true; }
    Keys.onEnterPressed: event => { activateCurrentUser(); event.accepted = true; }
    Keys.onSpacePressed: event => { activateCurrentUser(); event.accepted = true; }

    delegate: Item {
        id: accountRow
        width: root.width
        height: WinStyle.userSwitcherItemHeight
        Accessible.role: Accessible.ListItem
        Accessible.name: model.realName || model.name || ""
        Accessible.selected: ListView.isCurrentItem

        Rectangle {
            anchors.fill: parent
            radius: ControlMetrics.controlCornerRadius
            color: accountRow.ListView.isCurrentItem ? "#20FFFFFF"
                : pointer.containsMouse ? "#16FFFFFF" : "transparent"
            border.width: root.activeFocus && accountRow.ListView.isCurrentItem ? 1 : 0
            border.color: "#88FFFFFF"
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
