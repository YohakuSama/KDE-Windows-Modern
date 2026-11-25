import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

RowLayout {
    id: header

    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor, Kirigami.Theme.backgroundColor)
    property string title
    property bool showSwitch: false
    property bool switchEnabled: true
    property bool switchChecked: false

    property bool showAction: false
    property string actionText
    signal actionTriggered

    signal back
    signal switchToggled

    Layout.fillWidth: true
    Layout.preferredHeight: 48
    Layout.leftMargin: 12
    Layout.rightMargin: 16
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    spacing: 8

    PlasmaComponents3.ToolButton {
        objectName: "wmDetailBack"
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignVCenter
        text: i18n("Back")
        display: PlasmaComponents3.AbstractButton.IconOnly
        icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
        icon.width: 18
        icon.height: 18
        onClicked: header.back()
        PlasmaComponents3.ToolTip { text: parent.text }
    }

    PlasmaComponents3.Label {
        objectName: "wmDetailTitle"
        text: header.title
        color: Kirigami.Theme.textColor
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    PlasmaComponents3.Button {
        objectName: "wmDetailAction"
        visible: header.showAction
        text: header.actionText
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignVCenter
        onClicked: header.actionTriggered()
    }

    QQC2.Switch {
        id: radioSwitch
        objectName: "wmDetailSwitch"
        visible: header.showSwitch
        enabled: header.switchEnabled
        checked: header.switchChecked
        onToggled: {
            header.switchToggled();
            // Backend state remains authoritative, including failed radio
            // requests and hardware airplane-mode restrictions.
            checked = Qt.binding(() => header.switchChecked);
        }
        Accessible.name: header.title
        Layout.preferredWidth: 44
        Layout.preferredHeight: 32
        Layout.alignment: Qt.AlignVCenter
        padding: 0
        background: Rectangle {
            radius: 4
            color: "transparent"
            border.width: radioSwitch.activeFocus ? 1 : 0
            border.color: header.accent
        }
        contentItem: Item {}
        indicator: Rectangle {
            objectName: "wmDetailSwitchTrack"
            readonly property color fg: Kirigami.Theme.textColor
            x: (radioSwitch.width - width) / 2
            y: (radioSwitch.height - height) / 2
            width: 40
            height: 20
            radius: 10
            color: radioSwitch.checked ? header.accent : "transparent"
            border.width: radioSwitch.checked ? 0 : 1
            border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.70)
            opacity: radioSwitch.enabled ? 1 : 0.5
            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: (radioSwitch.checked !== radioSwitch.mirrored) ? parent.width - width - 4 : 4
                color: radioSwitch.checked ? ColorType.contrastingForeground(header.accent) : Kirigami.Theme.textColor
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }
    }
}
