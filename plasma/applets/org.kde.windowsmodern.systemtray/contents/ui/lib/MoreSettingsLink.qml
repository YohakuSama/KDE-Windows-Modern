import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

Item {
    id: root

    property string text
    property string kcm
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)

    signal clicked

    implicitHeight: 42
    implicitWidth: parent ? parent.width : 200
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 4
        color: ColorType.rowFill(root.dark, false, ma.containsMouse || root.activeFocus, ma.containsPress)
        border.width: root.activeFocus ? 1 : 0
        border.color: Kirigami.Theme.textColor
    }

    PlasmaComponents3.Label {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.text
        color: Kirigami.Theme.textColor
        opacity: 1
        font.pixelSize: 12
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
