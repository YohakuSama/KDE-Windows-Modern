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
import "lockText.js" as LockText
import "lockMetrics.js" as LockMetrics

FocusScope {
    id: sessionManager
    focus: true
    property var userListModel: null

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    readonly property int avatarSize: LockMetrics.avatarSize(width, height)
    property alias showPassword: passwordBox.showPassword

    property string customErrorMessage: ""
    readonly property int visibleBoundary: Math.round(form.y + passwordPanel.y + passwordPanel.height)

    signal passwordResult(string password)

    function clearPassword() {
        passwordBox.showPassword = false;
        passwordBox.forceActiveFocus();
        passwordBox.text = "";
    }

    function pulseError() {
        errorPulse.restart();
    }

    function startLogin() {
        const password = passwordBox.text;
        passwordBox.showPassword = false;
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    // Independent Windows-style layout: no inherited lower-half prompt.
    ColumnLayout {
        id: form
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: LockMetrics.formTop(sessionManager.height, implicitHeight)
        width: parent.width
        spacing: 8

    // Always show a user image or the Windows default account avatar.
    AccountAvatar {
        Layout.alignment: Qt.AlignHCenter
        size: sessionManager.avatarSize
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        Layout.bottomMargin: 8
        source: sessionManager.userListModel && sessionManager.userListModel.count > 0
            ? sessionManager.userListModel.get(0).icon : ""
    }

    // ── Username ──
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: sessionManager.width
        Layout.bottomMargin: 16
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: {
            if (sessionManager.userListModel && sessionManager.userListModel.count > 0) {
                const item = sessionManager.userListModel.get(0);
                if (item.realName) return item.realName;
                if (item.name) return item.name;
            }
            return "";
        }
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 24
        font.weight: Font.Normal
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
    }

    // Error text participates in layout only when present.
    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: sessionManager.width
        Layout.preferredHeight: Math.max(20, errorLabel.implicitHeight)
        Layout.bottomMargin: 0
        visible: sessionManager.customErrorMessage !== ""

        Text {
            id: errorLabel
            anchors.centerIn: parent
            width: parent.width
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: sessionManager.customErrorMessage !== ""
            text: sessionManager.customErrorMessage
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: LockMetrics.credentialFontSize
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
        id: passwordPanel
        Layout.fillWidth: true
        Layout.maximumWidth: LockMetrics.passwordWidth
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: LockMetrics.passwordHeight
        implicitHeight: LockMetrics.passwordHeight

        Rectangle {
            id: passwordBorder
            anchors.fill: parent
            color: "#40000000"
            border.color: "#66FFFFFF"
            radius: LockMetrics.fieldCornerRadius

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: LockMetrics.fieldFocusBarInset
                height: LockMetrics.fieldFocusBarHeight
                radius: LockMetrics.fieldFocusBarRadius
                color: "#4CC2FF"
                visible: passwordBox.activeFocus
            }
        }

        TextField {
            id: passwordBox
            anchors.left: parent.left
            anchors.right: revealButton.visible ? revealButton.left : loginButton.left
            anchors.rightMargin: Math.min(4, parent.width / 6)
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height

            property bool showPassword: false
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            placeholderText: LockText.tr("Password", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Password"), Qt.uiLanguage, Qt.locale().name)
            placeholderTextColor: "#A0A0A0"
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: LockMetrics.credentialFontSize
            color: "#FFFFFF"
            selectionColor: "#0078D4"
            selectedTextColor: "#FFFFFF"
            focus: true
            leftPadding: 8
            rightPadding: 8
            verticalAlignment: TextInput.AlignVCenter
            cursorVisible: visible && focus
            activeFocusOnTab: true

            background: Item {}

            onAccepted: {
                if (sessionManager.lockScreenUiVisible) {
                    sessionManager.startLogin();
                }
            }
        }

        CredentialToolButton {
            id: revealButton
            anchors.right: loginButton.left
            anchors.verticalCenter: parent.verticalCenter
            visible: passwordBox.text.length > 0
            text: LockText.tr("Show password", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Show password"), Qt.uiLanguage, Qt.locale().name)
            icon.name: "view-visible"
            icon.color: "#FFFFFF"
            onPressedChanged: passwordBox.showPassword = pressed && visible
            onVisibleChanged: if (!visible) passwordBox.showPassword = false
            onActiveFocusChanged: if (!activeFocus && !pressed) passwordBox.showPassword = false
            background: Rectangle {
                radius: LockMetrics.fieldButtonRadius
                color: revealButton.hovered || revealButton.pressed ? "#33FFFFFF" : "transparent"
            }
        }

        CredentialToolButton {
            id: loginButton
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter

            text: LockText.tr("Sign in", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in"), Qt.uiLanguage, Qt.locale().name)
            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
            opacity: passwordBox.text.length > 0 ? 1 : 0.65
            icon.color: hovered ? "#FFFFFF" : "#E0E0E0"

            onClicked: if (sessionManager.lockScreenUiVisible) sessionManager.startLogin()
            Keys.onEnterPressed: clicked()
            Keys.onReturnPressed: clicked()

            background: Rectangle {
                color: parent.hovered ? "#33FFFFFF" : "transparent"
                radius: LockMetrics.fieldButtonRadius
            }
        }
    }

    FailableLabel {
        kind: ScreenLocker.Authenticator.Fingerprint
        label: LockText.tr("(or scan your fingerprint on the reader)", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "(or scan your fingerprint on the reader)"), Qt.uiLanguage, Qt.locale().name)
    }
    FailableLabel {
        kind: ScreenLocker.Authenticator.Smartcard
        label: LockText.tr("(or scan your smartcard)", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "(or scan your smartcard)"), Qt.uiLanguage, Qt.locale().name)
    }
    }

    SequentialAnimation {
        id: errorPulse
        NumberAnimation { target: errorLabel; property: "scale"; from: 1; to: 1.06; duration: Kirigami.Units.shortDuration > 0 ? 100 : 0 }
        NumberAnimation { target: errorLabel; property: "scale"; to: 1; duration: Kirigami.Units.shortDuration > 0 ? 100 : 0 }
    }

    // Both credential actions retain the native ToolButton input behavior,
    // but only draw explicitly mapped Windows artwork. If the local import
    // is absent, show the real action label instead of a toolkit fallback.
    component CredentialToolButton : ToolButton {
        id: actionButton
        width: Math.max(0, Math.min(parent.width / 3, Math.max(LockMetrics.submitButtonMinWidth,
            actionGlyph.nativeSource.length > 0 ? LockMetrics.submitButtonMinWidth : actionLabel.implicitWidth + 8)))
        height: Math.min(parent.height, 26)
        padding: 2
        display: AbstractButton.IconOnly
        Accessible.name: text
        contentItem: Item {
            NativeGlyph {
                id: actionGlyph
                anchors.centerIn: parent
                width: Math.max(0, Math.min(14, parent.width, parent.height))
                height: width
                roleName: actionButton.icon.name
                foreground: actionButton.icon.color
            }
            Text {
                id: actionLabel
                anchors.fill: parent
                visible: actionGlyph.nativeSource.length === 0
                text: actionButton.text
                font.family: Kirigami.Theme.defaultFont.family
                font.pixelSize: LockMetrics.submitButtonFontSize
                textFormat: Text.PlainText
                color: actionButton.icon.color
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
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
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: sessionManager.width
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

}
