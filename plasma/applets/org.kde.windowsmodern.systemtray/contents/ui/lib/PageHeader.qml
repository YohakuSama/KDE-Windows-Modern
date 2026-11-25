import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

RowLayout {
    id: header

    Win11Palette { id: fluent }

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
        id: backButton
        Layout.preferredWidth: fluent.controlHeight
        Layout.preferredHeight: fluent.controlHeight
        icon.width: fluent.menuIconSize
        icon.height: fluent.menuIconSize
        background: Rectangle {
            radius: fluent.controlRadius
            color: backButton.down ? fluent.controlPressed
                : backButton.hovered || backButton.activeFocus ? fluent.controlHover : "transparent"
            border.width: backButton.activeFocus ? 1 : 0
            border.color: fluent.accent
        }
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
        elide: Text.ElideRight
    }

    PlasmaComponents3.Switch {
        id: toggle
        Layout.preferredWidth: 48
        Layout.preferredHeight: fluent.controlHeight
        padding: 0
        // Override only the indicator: native Switch owns keyboard, touch,
        // accessibility and checked/toggled semantics.
        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 20
            width: implicitWidth
            height: implicitHeight
            x: (toggle.width - width) / 2
            y: (toggle.height - height) / 2
            radius: height / 2
            color: toggle.checked ? fluent.accent : fluent.switchTrack
            opacity: toggle.enabled ? 1 : 0.42
            border.width: toggle.activeFocus || !toggle.checked ? 1 : 0
            border.color: toggle.activeFocus ? fluent.text : fluent.switchOutline
            Rectangle {
                readonly property bool atEnd: toggle.checked !== toggle.mirrored
                width: toggle.down ? 14 : 12
                height: width
                radius: width / 2
                x: atEnd ? parent.width - width - 4 : 4
                anchors.verticalCenter: parent.verticalCenter
                color: toggle.checked ? fluent.accentText : fluent.text
                Behavior on x { NumberAnimation { duration: 100 } }
            }
        }
        visible: header.showSwitch
        enabled: header.switchEnabled
        checked: header.switchChecked
        onToggled: header.switchToggled()
        Accessible.name: header.title
        Layout.alignment: Qt.AlignVCenter
    }
}
