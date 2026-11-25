import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

RowLayout {
    id: header

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
        text: header.title
        color: Kirigami.Theme.textColor
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    PlasmaComponents3.Button {
        visible: header.showAction
        text: header.actionText
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignVCenter
        onClicked: header.actionTriggered()
    }

    PlasmaComponents3.Switch {
        visible: header.showSwitch
        enabled: header.switchEnabled
        checked: header.switchChecked
        onToggled: header.switchToggled()
        Accessible.name: header.title
        Layout.alignment: Qt.AlignVCenter
    }
}
