// A white, icon-only button for the lock screen's status row.
import QtQuick
import QtQuick.Controls
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmaComponents3.ToolButton {
    implicitWidth: 40
    implicitHeight: 40
    width: 40
    height: 40
    icon.width: 18
    icon.height: 18
    icon.color: "#FFFFFF"
    display: AbstractButton.IconOnly
    flat: true
    focusPolicy: Qt.NoFocus
    background: Rectangle {
        radius: 4
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
