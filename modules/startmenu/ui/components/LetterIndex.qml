// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../code/controlMetrics.js" as ControlMetrics
import "../code/startMenuMetrics.js" as Metrics

FocusScope {
    id: root
    objectName: "wmStartLetterIndexOverlay"
    property bool opened: false
    property var letters: []
    signal letterActivated(string letter)
    signal backRequested()
    readonly property alias currentIndex: grid.currentIndex

    function focusIndex() {
        const first = letters.findIndex(entry => entry.available);
        grid.currentIndex = first;
        grid.forceActiveFocus();
    }

    visible: opened || opacity > 0.001
    enabled: opened
    opacity: opened ? 1 : 0
    scale: opened ? 1 : 0.975
    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Metrics.openSpline : Metrics.closeSpline
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Metrics.openSpline : Metrics.closeSpline
        }
    }
    onOpenedChanged: if (opened) focusIndex()

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.backRequested()
        onWheel: wheel => { wheel.accepted = true; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("All")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            AToolButton {
                objectName: "wmStartLetterIndexBack"
                text: i18n("Back")
                iconName: "go-previous-symbolic"
                mirror: true
                flat: true
                linkStyle: true
                onClicked: root.backRequested()
                Keys.onDownPressed: root.focusIndex()
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: grid
                objectName: "wmStartLetterIndexGrid"
                anchors.centerIn: parent
                width: Math.min(parent.width, 4 * 52)
                height: Math.max(0, Math.min(parent.height, Math.ceil(count / 4) * cellHeight))
                layoutDirection: grid.LayoutMirroring.enabled ? Qt.RightToLeft : Qt.LeftToRight
                cellWidth: Math.max(1, width / 4)
                cellHeight: 48
                clip: true
                model: root.letters
                keyNavigationEnabled: false
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1
                focus: true

                function activateRow(row) {
                    if (row >= 0 && row < count && model[row].available)
                        root.letterActivated(model[row].label);
                }
                function move(step) {
                    let row = currentIndex + step;
                    while (row >= 0 && row < count && !model[row].available)
                        row += step;
                    if (row >= 0 && row < count) {
                        currentIndex = row;
                        positionViewAtIndex(row, GridView.Contain);
                    }
                }
                function jumpEdge(last) {
                    const idx = last
                        ? root.letters.map(item => !!item.available).lastIndexOf(true)
                        : root.letters.findIndex(item => !!item.available);
                    if (idx >= 0) {
                        currentIndex = idx;
                        positionViewAtIndex(idx, GridView.Contain);
                    }
                }
                Keys.onPressed: event => {
                    const hStep = grid.LayoutMirroring.enabled ? -1 : 1;
                    switch (event.key) {
                    case Qt.Key_Left: move(-hStep); break;
                    case Qt.Key_Right: move(hStep); break;
                    case Qt.Key_Up: move(-4); break;
                    case Qt.Key_Down: move(4); break;
                    case Qt.Key_Home: jumpEdge(false); break;
                    case Qt.Key_End: jumpEdge(true); break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space: if (!event.isAutoRepeat) activateRow(currentIndex); break;
                    default: return;
                    }
                    event.accepted = true;
                }
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    objectName: "wmStartLetterIndex_" + modelData.label
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool available: !!modelData.available
                    readonly property bool hovered: tileMouse.containsMouse
                    readonly property bool selected: GridView.isCurrentItem && grid.activeFocus
                    readonly property color foreground: Kirigami.Theme.textColor

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: ControlMetrics.controlCornerRadius
                        color: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b,
                            tile.available ? (tileMouse.containsPress ? 0.12
                                : tile.hovered || tile.selected ? 0.07 : 0) : 0)
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? ControlMetrics.microInteractionDuration : 0 } }
                    }
                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 6)
                        text: tile.modelData.icon ? "" : tile.modelData.label
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        opacity: tile.available ? 1 : 0.34
                        font.pixelSize: 20
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        visible: !!tile.modelData.icon
                        source: tile.modelData.icon || ""
                        opacity: tile.available ? 1 : 0.34
                    }
                    Accessible.role: Accessible.Button
                    Accessible.ignored: !available
                    Accessible.name: i18n("Jump to %1", modelData.label === "world"
                        ? i18n("Other alphabets") : modelData.label)
                    Accessible.onPressAction: grid.activateRow(index)
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: grid.activateRow(tile.index)
                    }
                }
                PlasmaComponents3.ScrollBar.vertical: StartScrollBar { scrolling: grid.moving }
            }
        }
    }
    Keys.onEscapePressed: root.backRequested()
}
