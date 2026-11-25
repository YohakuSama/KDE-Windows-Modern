/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2025 Windows Modern Theme

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.breeze.components

SessionManagementScreen {
    id: sessionManager

    actionItems: [ Item { visible: false } ]

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property alias showPassword: passwordBox.showPassword

    showUserList: true
    property string customErrorMessage: ""
    notificationMessage: "" // Silence default top-aligned banner

    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing

    signal passwordResult(string password)

    onUserSelected: {
        const nextControl = passwordBox;
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    function startLogin() {
        const password = passwordBox.text
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    Component.onCompleted: {
        if (sessionManager.userList) {
            sessionManager.userList.visible = false;
            sessionManager.userList.opacity = 0;
            sessionManager.userList.height = 0;
        }
    }

    // Always show a user image or the Windows default account avatar.
    AccountAvatar {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 140
        Layout.preferredHeight: 140
        Layout.bottomMargin: 16
        source: sessionManager.userListModel && sessionManager.userListModel.count > 0
            ? sessionManager.userListModel.get(0).icon : ""
    }

    // ── Username ──
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 4
        text: {
            if (sessionManager.userListModel && sessionManager.userListModel.count > 0) {
                const item = sessionManager.userListModel.get(0);
                if (item.realName) return item.realName;
                if (item.name) return item.name;
            }
            return "";
        }
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 32
        font.weight: Font.Normal
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Custom Error Message (Windows 10 style) ──
    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 20
        Layout.bottomMargin: 0

        Text {
            anchors.centerIn: parent
            visible: sessionManager.customErrorMessage !== ""
            text: sessionManager.customErrorMessage
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: 14
            font.italic: true
            color: "#A0A0A0"
            horizontalAlignment: Text.AlignHCenter
            // Screen readers announce "Unlocking failed" and the like.
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            Accessible.ignored: !visible
        }
    }

    // ── Password field + submit button ──
    Item {
        Layout.fillWidth: true
        Layout.maximumWidth: 280
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 42
        implicitHeight: 42

        Rectangle {
            id: passwordBorder
            anchors.fill: parent
            color: "#40000000"
            border.color: "#66FFFFFF"
            radius: 4

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                height: 2
                radius: 1
                color: "#4CC2FF"
                visible: passwordBox.activeFocus
            }
        }

        TextField {
            id: passwordBox
            anchors.left: parent.left
            anchors.right: loginButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            property bool showPassword: false
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            placeholderText: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Password")
            placeholderTextColor: "#A0A0A0"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: 14
            color: "#FFFFFF"
            focus: true
            leftPadding: 8
            verticalAlignment: TextInput.AlignVCenter
            cursorVisible: visible && focus
            activeFocusOnTab: true

            background: Item {}

            onAccepted: {
                if (sessionManager.lockScreenUiVisible) {
                    sessionManager.startLogin();
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left && !text) {
                    sessionManager.userList.decrementCurrentIndex();
                    event.accepted = true
                }
                if (event.key === Qt.Key_Right && !text) {
                    sessionManager.userList.incrementCurrentIndex();
                    event.accepted = true
                }
            }

            Connections {
                target: root
                function onClearPassword() {
                    passwordBox.forceActiveFocus()
                    passwordBox.text = "";
                }
                function onNotificationRepeated() {
                    sessionManager.playHighlightAnimation();
                }
            }
        }

        ToolButton {
            id: loginButton
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38

            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
            visible: passwordBox.text.length > 0
            icon.color: hovered ? "#4CC2FF" : "#A0A0A0"

            onClicked: sessionManager.startLogin()
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()

            background: Rectangle {
                color: parent.hovered ? "#33FFFFFF" : "transparent"
                radius: 4
            }
        }
    }

    component FailableLabel : PlasmaComponents3.Label {
        id: _failableLabel
        required property int kind
        required property string label

        visible: authenticator.authenticatorTypes & kind
        text: label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 12
        color: "#A0A0A0"

        RejectPasswordAnimation {
            id: _rejectAnimation
            target: _failableLabel
            onFinished: _timer.restart()
        }

        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _rejectAnimation.start()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: {
                _failableLabel.text = Qt.binding(() => _failableLabel.label)
            }
        }
    }

    FailableLabel {
        kind: ScreenLocker.Authenticator.Fingerprint
        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your fingerprint on the reader)")
    }
    FailableLabel {
        kind: ScreenLocker.Authenticator.Smartcard
        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your smartcard)")
    }
}
