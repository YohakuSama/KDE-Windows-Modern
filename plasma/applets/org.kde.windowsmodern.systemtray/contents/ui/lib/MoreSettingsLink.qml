import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    Win11Palette { id: fluent }

    property string text
    property string kcm

    signal clicked

    implicitHeight: Math.max(42, linkLabel.implicitHeight + 16)
    activeFocusOnTab: true
    Accessible.role: Accessible.Link
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    implicitWidth: parent ? parent.width : 200

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: fluent.controlRadius
        color: ma.containsPress ? fluent.controlPressed
            : ma.containsMouse || root.activeFocus ? fluent.controlHover : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: fluent.accent
    }

    PlasmaComponents3.Label {
        id: linkLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: fluent.accent
        font: Kirigami.Theme.defaultFont
        elide: Text.ElideRight
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
