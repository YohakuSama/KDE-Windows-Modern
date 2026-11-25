// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string accountName
    property url accountImage
    property string message
    readonly property int avatarSize: Math.max(1, Math.floor(Math.min(WinStyle.avatarSize, width * 0.6, height * 0.25)))

    ColumnLayout {
        id: form
        objectName: "wmWelcomeForm"
        width: Math.min(root.width, 380)
        height: implicitHeight
        anchors.centerIn: parent
        spacing: 8

        WinAvatar {
            objectName: "wmWelcomeAvatar"
            size: root.avatarSize
            source: root.accountImage
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 4
        }
        Text {
            objectName: "wmWelcomeName"
            Layout.fillWidth: true
            font.family: WinStyle.fontFamily
            font.pixelSize: Math.min(WinStyle.usernamePixelSize, Math.max(14, root.height / 10))
            color: WinStyle.foregroundColor
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.accountName
        }
        SignInProgress {
            objectName: "wmWelcomeRing"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(36, Math.max(18, root.height / 8))
            Layout.preferredHeight: Layout.preferredWidth
            running: root.visible
        }
        Text {
            objectName: "wmWelcomeText"
            Layout.fillWidth: true
            text: root.message
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: WinStyle.foregroundColor
            horizontalAlignment: Text.AlignHCenter
            font.family: WinStyle.fontFamily
            font.pixelSize: Math.min(24, Math.max(14, root.height / 12))
        }
    }
}
