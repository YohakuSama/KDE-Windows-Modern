// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root
    objectName: "wmStartLetterIndexOverlay"
    property bool opened: false
    property var letters: []
    signal letterActivated(string letter)
    signal backRequested()

    visible: opened || opacity > 0.001
    opacity: opened ? 1 : 0
    scale: opened ? 1 : 0.975
    focus: opened
    z: 20

    Behavior on opacity {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 190; easing.type: Easing.OutBack }
    }
    onOpenedChanged: if (opened) forceActiveFocus()

    Keys.onEscapePressed: event => {
        event.accepted = true;
        root.backRequested();
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.08)
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.AllButtons
        onClicked: mouse => { mouse.accepted = true; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8
        z: 1

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("All")
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Kirigami.Theme.textColor
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.ToolButton {
                objectName: "wmStartLetterIndexBack"
                text: i18n("Back")
                icon.name: "go-previous"
                onClicked: root.backRequested()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 4 * 58 + 3 * 14)
                columns: 4
                rowSpacing: 8
                columnSpacing: 14

                Repeater {
                    model: root.letters
                    delegate: Item {
                        id: tile
                        required property var modelData
                        objectName: "wmStartLetterIndex_" + modelData.label
                        readonly property bool available: modelData.available
                        readonly property bool hovered: tileMouse.containsMouse
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 44
                        scale: hovered ? 1.075 : 1
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: tile.hovered && tile.available
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                    Kirigami.Theme.highlightColor.b, 0.16)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            text: tile.modelData.label
                            color: !tile.available
                                ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.34)
                                : tile.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            font.pixelSize: 19
                            font.weight: tile.available ? Font.Medium : Font.Normal
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.ignored: !available
                        Accessible.name: i18n("Jump to %1", modelData.label)
                        Accessible.onPressAction: if (available) root.letterActivated(modelData.label)
                        activeFocusOnTab: available
                        Keys.onReturnPressed: if (available) root.letterActivated(modelData.label)
                        Keys.onEnterPressed: if (available) root.letterActivated(modelData.label)
                        Keys.onSpacePressed: if (available) root.letterActivated(modelData.label)

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            enabled: tile.available
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.letterActivated(tile.modelData.label)
                        }
                    }
                }
            }
        }
    }
}
