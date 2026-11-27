import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType
import "../components" as Components
import "../js/controlMetrics.js" as ControlMetrics

Item {
    id: row

    property string iconSource
    property string text
    property bool selected: false
    property int inset: 8
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor,
        Qt.color(ColorType.cardFill(dark, false)), 4.5)
    property Component trailing: null

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 40
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: row.text
    Accessible.onPressAction: row.clicked()
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) row.clicked(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) row.clicked(); }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) row.clicked(); }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.inset
        anchors.rightMargin: row.inset
        radius: ControlMetrics.controlCornerRadius
        color: ColorType.rowFill(row.dark, row.selected, rowMouse.containsMouse, rowMouse.containsPress)
        border.width: row.activeFocus ? 1 : 0
        border.color: row.accent

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: Math.min(18, parent.height - 8)
            radius: 1.5
            visible: row.selected
            color: row.accent
        }

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                visible: row.iconSource.length > 0
                Components.NativeGlyph {
                    anchors.fill: parent
                    roleName: row.iconSource
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.text
                textFormat: Text.PlainText
                color: Kirigami.Theme.textColor
                font.pixelSize: 12
                font.weight: row.selected ? Font.DemiBold : Font.Normal
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
