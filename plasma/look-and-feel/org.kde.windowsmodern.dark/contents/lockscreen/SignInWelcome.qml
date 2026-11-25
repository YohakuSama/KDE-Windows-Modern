// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string accountName
    property url accountImage
    property string message
    property real avatarTop: -1
    readonly property int avatarSize: Math.max(1, Math.floor(Math.min(WinStyle.avatarSize, width * 0.6, height * 0.32)))
    readonly property real verticalGap: Math.min(18, Math.max(4, height / 30))

    ColumnLayout {
        id: form
        objectName: "wmWelcomeForm"
        width: Math.min(root.width, 380)
        height: implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, Math.min(root.height - height,
            root.avatarTop >= 0 ? root.avatarTop : (root.height - height) / 2))
        spacing: root.verticalGap

        WinAvatar {
            objectName: "wmWelcomeAvatar"
            size: root.avatarSize
            source: root.accountImage
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 0
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
            Layout.preferredWidth: Math.min(36, Math.max(18, root.height / 9))
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
