import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: row

    Win11Palette { id: fluent }

    property string iconSource
    property string text
    property bool selected: false
    property Component trailing: null

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(36, contentRow.implicitHeight + 12)
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: row.text
    Accessible.onPressAction: row.clicked()
    Keys.onReturnPressed: row.clicked()
    Keys.onEnterPressed: row.clicked()
    Keys.onSpacePressed: row.clicked()

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: fluent.controlRadius
        color: rowMouse.containsPress ? fluent.controlPressed
            : row.selected ? fluent.selectionFill
            : rowMouse.containsMouse || row.activeFocus ? fluent.controlHover : "transparent"
        border.width: row.activeFocus ? 1 : 0
        border.color: fluent.accent

        Rectangle {
            visible: row.selected
            width: 3
            height: 16
            radius: 1.5
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: fluent.accent
        }

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Kirigami.Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: row.iconSource
                color: fluent.text
                isMask: true
                visible: row.iconSource.length > 0
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.text
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.defaultFont
                elide: Text.ElideRight
            }

            Loader {
                Layout.preferredWidth: item ? item.width : 0
                Layout.preferredHeight: item ? item.height : 0
                visible: row.trailing !== null
                sourceComponent: row.trailing
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
