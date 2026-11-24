import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: row

    property string iconSource
    property string text
    property bool selected: false
    property bool referenceSelection: false
    property Component trailing: null

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: referenceSelection ? 40 : 36
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: 4
        color: row.selected
            ? (row.referenceSelection ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.055)
                : Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.15))
            : (rowMouse.containsMouse || row.activeFocus
                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                : "transparent")

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 16
            radius: 1.5
            visible: row.referenceSelection && row.selected
            color: Kirigami.Theme.highlightColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Kirigami.Icon {
                Layout.preferredWidth: row.referenceSelection ? 16 : 20
                Layout.preferredHeight: Layout.preferredWidth
                roundToIconSize: false
                source: row.iconSource
                color: row.selected && !row.referenceSelection ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                isMask: true
                visible: row.iconSource.length > 0
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.text
                color: Kirigami.Theme.textColor
                font.pixelSize: row.referenceSelection ? 13 : 11
                font.bold: row.selected && !row.referenceSelection
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
