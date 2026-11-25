// A white, icon-only button for the lock screen's status row.
import QtQuick
import QtQuick.Controls
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmaComponents3.ToolButton {
    id: control
    width: 32
    height: 32
    icon.color: "#FFFFFF"
    icon.width: 16
    icon.height: 16
    background: Rectangle {
        radius: 4
        color: control.down ? "#0DFFFFFF" : control.hovered || control.activeFocus ? "#17FFFFFF" : "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: "#4CC2FF"
    }
    display: AbstractButton.IconOnly
    flat: true
    focusPolicy: Qt.NoFocus
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Accessible.name: text
    PlasmaComponents3.ToolTip.text: text
    PlasmaComponents3.ToolTip.visible: hovered && text.length > 0
    PlasmaComponents3.ToolTip.delay: 500
}
