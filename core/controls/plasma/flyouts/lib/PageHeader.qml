import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../components" as Components
import "../js/trayMetrics.js" as TrayMetrics

RowLayout {
    id: header

    property color shellAccent: Kirigami.Theme.highlightColor
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

    Components.NativeToolButton {
        objectName: "wmDetailBack"
        nativeRole: header.LayoutMirroring.enabled || Application.layoutDirection === Qt.RightToLeft
            ? "go-next-symbolic" : "go-previous-symbolic"
        Layout.preferredWidth: nativeIcon.length > 0 ? 36 : implicitWidth
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignVCenter
        text: i18n("Back")
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
        Layout.preferredHeight: TrayMetrics.detailActionButtonHeight
        Layout.alignment: Qt.AlignVCenter
        onClicked: header.actionTriggered()
    }

    FluentSwitch {
        id: radioSwitch
        shellAccent: header.shellAccent
        objectName: "wmDetailSwitch"
        visible: header.showSwitch
        enabled: header.switchEnabled
        checked: header.switchChecked
        onToggled: {
            header.switchToggled();
            checked = Qt.binding(() => header.switchChecked);
        }
        Accessible.name: header.title
        Layout.preferredWidth: 44
        Layout.preferredHeight: 32
        Layout.alignment: Qt.AlignVCenter
    }
}
