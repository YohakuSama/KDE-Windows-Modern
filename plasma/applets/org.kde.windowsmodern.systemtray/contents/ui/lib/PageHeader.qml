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

    signal back
    signal switchToggled

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(32, Kirigami.Units.gridUnit * 2)
    Layout.leftMargin: 10
    Layout.rightMargin: 10
    Layout.bottomMargin: 8
    spacing: 6

    PlasmaComponents3.ToolButton {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
        Layout.alignment: Qt.AlignVCenter
        text: i18n("Back")
        display: PlasmaComponents3.AbstractButton.IconOnly
        icon.name: Application.layoutDirection === Qt.RightToLeft ? "go-next" : "go-previous"
        onClicked: header.back()
        PlasmaComponents3.ToolTip { text: parent.text }
    }

    PlasmaComponents3.Label {
        text: header.title
        color: Kirigami.Theme.textColor
        font.weight: Font.DemiBold
        Layout.fillWidth: true
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
