/*
    SPDX-FileCopyrightText: 2022 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2025 Windows Modern Theme

    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3

import org.kde.breeze.components
import "lockText.js" as LockText
import "lockMetrics.js" as LockMetrics

FocusScope {
    id: screen
    focus: true
    property var userListModel: null
    readonly property int avatarSize: LockMetrics.avatarSize(width, height)

    Component.onCompleted: loginButton.forceActiveFocus()

    ColumnLayout {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: LockMetrics.formTop(screen.height, implicitHeight)
        width: parent.width
        spacing: 8

    AccountAvatar {
        Layout.alignment: Qt.AlignHCenter
        size: screen.avatarSize
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        Layout.bottomMargin: 8
        source: screen.userListModel && screen.userListModel.count > 0
            ? screen.userListModel.get(0).icon : ""
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: screen.width
        Layout.bottomMargin: 16
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: {
            if (!screen.userListModel || screen.userListModel.count === 0) return "";
            const user = screen.userListModel.get(0);
            return user.realName || user.name || "";
        }
        color: "white"
        font.pixelSize: 24
        horizontalAlignment: Text.AlignHCenter
    }

    PlasmaComponents3.Button {
        id: loginButton
        focus: true
        text: LockText.tr("Sign in", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in"), Qt.uiLanguage, Qt.locale().name)
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.min(144, screen.width)
        Layout.preferredHeight: LockMetrics.passwordHeight
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
}
