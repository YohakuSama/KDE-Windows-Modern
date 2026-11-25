// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import "SignInMetrics.js" as SignInMetrics

Item {
    id: root
    property string accountName
    property url accountImage
    property string message
    readonly property int avatarSize: SignInMetrics.avatarSize(width, height)
    ColumnLayout {
        id: form
        objectName: "wmWelcomeForm"
        width: Math.min(root.width, 380)
        height: implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: SignInMetrics.formTop(root.height, height, root.avatarSize)
        spacing: 8
        SignInAvatar {
            objectName: "wmWelcomeAvatar"
            size: root.avatarSize
            source: root.accountImage
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 10
        }
        Text {
            objectName: "wmWelcomeName"
            Layout.fillWidth: true
            font.family: WinStyle.fontFamily
            font.pixelSize: WinStyle.usernamePixelSize
            color: WinStyle.foregroundColor
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.accountName
        }
        SignInProgress {
            objectName: "wmWelcomeRing"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 22
            Layout.bottomMargin: 22
            running: root.visible
        }
        Text {
            objectName: "wmWelcomeText"
            Layout.fillWidth: true
            text: root.message
            textFormat: Text.PlainText
            color: WinStyle.foregroundColor
            horizontalAlignment: Text.AlignHCenter
            font.family: WinStyle.fontFamily
            font.pixelSize: 24
        }
    }
}
