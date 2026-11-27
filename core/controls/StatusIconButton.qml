// A white, icon-only button for the lock screen's status row.
import QtQuick
import QtQuick.Controls
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "controlMetrics.js" as ControlMetrics

PlasmaComponents3.ToolButton {
    id: button
    contentItem: Item {
        NativeGlyph {
            anchors.centerIn: parent
            width: Math.min(16, parent.width, parent.height)
            height: width
            roleName: button.icon.name
            foreground: "#FFFFFF"
        }
    }
    implicitWidth: 32
    implicitHeight: 32
    width: 32
    height: 32
    icon.width: 16
    icon.height: 16
    icon.color: "#FFFFFF"
    display: AbstractButton.IconOnly
    flat: true
    focusPolicy: Qt.NoFocus
    background: Rectangle {
        radius: ControlMetrics.controlCornerRadius
        color: parent.down ? "#33FFFFFF" : parent.hovered ? "#20FFFFFF" : "transparent"
        border.width: parent.activeFocus ? 1 : 0
        border.color: "#FFFFFF"
    }
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Accessible.name: text
    PlasmaComponents3.ToolTip.text: text
    PlasmaComponents3.ToolTip.visible: hovered && text.length > 0
    PlasmaComponents3.ToolTip.delay: 500
}
