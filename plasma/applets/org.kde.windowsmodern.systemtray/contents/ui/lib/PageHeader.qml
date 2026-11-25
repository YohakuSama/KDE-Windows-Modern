// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

RowLayout {
    id: header
    property string title
    property bool showSwitch: false
    property bool switchEnabled: true
    property bool switchChecked: false
    signal back
    signal switchToggled
    Layout.fillWidth: true
    Layout.preferredHeight: 48
    Layout.minimumHeight: 48
    Layout.leftMargin: 12
    Layout.rightMargin: 16
    Layout.bottomMargin: 4
    spacing: 8

    PlasmaComponents3.ToolButton {
        id: backButton
        objectName: "wmPageBack"
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        Layout.alignment: Qt.AlignVCenter
        text: i18n("Back")
        display: PlasmaComponents3.AbstractButton.IconOnly
        icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next-symbolic" : "go-previous-symbolic"
        icon.width: 16
        icon.height: 16
        padding: 0
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: backButton.icon.name
                roundToIconSize: false
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
        background: Rectangle {
            radius: 4
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, backButton.down ? 0.12
                    : backButton.hovered || backButton.activeFocus ? 0.07 : 0)
        }
        onClicked: header.back()
        PlasmaComponents3.ToolTip { text: parent.text }
    }

    PlasmaComponents3.Label {
        objectName: "wmPageTitle"
        text: header.title
        textFormat: Text.PlainText
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Kirigami.Theme.textColor
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        elide: Text.ElideRight
    }

    T.Switch {
        id: radio
        objectName: "wmPageSwitch"
        visible: header.showSwitch
        enabled: header.switchEnabled
        checked: header.switchChecked
        Layout.preferredWidth: 44
        Layout.preferredHeight: 32
        Layout.alignment: Qt.AlignVCenter
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.name: header.title
        onToggled: header.switchToggled()
        indicator: Rectangle {
            x: (radio.width - width) / 2
            y: (radio.height - height) / 2
            width: 36
            height: 20
            radius: 10
            color: radio.checked ? Kirigami.Theme.highlightColor : "transparent"
            border.width: 1
            border.color: radio.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            opacity: radio.enabled ? 1 : 0.5
            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: radio.visualPosition * (parent.width - width - 8) + 4
                color: radio.checked ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            }
        }
    }
}
