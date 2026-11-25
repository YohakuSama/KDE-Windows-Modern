import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

ColumnLayout {
    id: tile

    Win11Palette { id: fluent }

    property string iconSource
    property string label
    property string tooltipText: ""
    property bool active: false
    property bool included: true
    property string orderKey: ""
    property Item orderView: null
    property real buttonHeight: -1
    readonly property int orderIndex: orderView ? orderView.visibleKeys.indexOf(orderKey) : -1
    readonly property bool reordering: orderView !== null && orderView.dragKey === orderKey

    // A stable three-column grid, with vacant cells in a partial final row.
    x: orderView && orderIndex >= 0 ? (orderIndex % 3) * (orderView.cellWidth + orderView.columnGap) : 0
    y: orderView && orderIndex >= 0 ? Math.floor(orderIndex / 3) * orderView.rowStride : 0
    width: orderView ? orderView.cellWidth : implicitWidth
    height: orderView ? orderView.rowHeight : implicitHeight
    visible: included
    z: reordering ? 10 : 0
    opacity: reordering ? 0.85 : 1
    transform: Translate {
        x: tile.reordering ? tile.orderView.dragOffsetX : 0
        y: tile.reordering ? tile.orderView.dragOffsetY : 0
    }
    TileReorderHandler { hostTile: tile }

    function focusForKeyboard() {
        if (toggleAvailable)
            forceActiveFocus(Qt.TabFocusReason);
        else
            arrowMA.forceActiveFocus(Qt.TabFocusReason);
    }

    onActiveFocusChanged: {
        if (activeFocus && orderView)
            orderView.ensureVisible(orderKey);
    }
    Keys.onPressed: event => {
        if (orderView && orderView.handleTileKey(orderKey, event.key, event.modifiers))
            event.accepted = true;
    }
    property bool toggleAvailable: true

    signal clicked
    signal arrowClicked
    signal rightClicked
    signal middleClicked

    activeFocusOnTab: toggleAvailable

    Accessible.role: Accessible.CheckBox
    Accessible.name: tile.label
    Accessible.checked: tile.active
    Accessible.onPressAction: if (tile.toggleAvailable) tile.clicked()
    Keys.onReturnPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onEnterPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onSpacePressed: if (tile.toggleAvailable) tile.clicked()

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fg: active ? ColorType.contrastingForeground(accent) : Kirigami.Theme.textColor

    spacing: 6
    Layout.fillWidth: true
    // Width is supplied by the explicitly sized three-column viewport.
    // A zero preferred-width hint is not a valid tile size.

    Rectangle {
        id: bg
        Layout.fillWidth: true
        Layout.preferredHeight: tile.buttonHeight > 0 ? tile.buttonHeight : width / 2
        radius: fluent.controlRadius
        border.width: 1
        border.color: tile.activeFocus ? fluent.text : active ? "transparent" : fluent.controlBorder
        color: active ? accent : fluent.controlFill

        // Independent hover/press feedback: the chevron opens details and
        // must not look like a press on the toggle itself.
        Rectangle {
            x: 2; y: 2
            width: Math.max(0, toggleMA.width - 3)
            height: Math.max(0, bg.height - 4)
            radius: 3
            color: Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b,
                toggleMA.containsPress ? 0.14 : toggleMA.containsMouse ? 0.08 : 0)
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Rectangle {
            x: toggleMA.width + 1; y: 2
            width: Math.max(0, arrowMA.width - 3)
            height: Math.max(0, bg.height - 4)
            radius: 3
            border.width: arrowMA.activeFocus ? 1 : 0
            border.color: tile.fg
            color: Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b,
                arrowMA.containsPress ? 0.14 : arrowMA.containsMouse ? 0.08 : 0)
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: tile.tooltipText
            subText: ""
            textFormat: Text.PlainText
        }

        MouseArea {
            id: toggleMA
            enabled: tile.toggleAvailable
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.60
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    tile.rightClicked();
                } else if (mouse.button === Qt.MiddleButton) {
                    tile.middleClicked();
                } else {
                    tile.clicked();
                }
            }
        }

        MouseArea {
            id: arrowMA
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.40
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            onActiveFocusChanged: if (activeFocus && tile.orderView) tile.orderView.ensureVisible(tile.orderKey)
            Accessible.role: Accessible.Button
            Accessible.name: i18n("%1 details", tile.label)
            Accessible.onPressAction: tile.arrowClicked()
            Keys.onReturnPressed: tile.arrowClicked()
            Keys.onEnterPressed: tile.arrowClicked()
            Keys.onSpacePressed: tile.arrowClicked()
            onClicked: tile.arrowClicked()
        }

        Kirigami.Icon {
            x: toggleMA.x + (toggleMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: width
            source: tile.iconSource
            roundToIconSize: false
            opacity: tile.toggleAvailable ? 1 : 0.55
            color: tile.fg
            isMask: true
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: arrowMA.x
            width: 1
            height: parent.height * 0.5
            visible: toggleMA.containsMouse || arrowMA.containsMouse || arrowMA.activeFocus
            color: active ? Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, 0.28) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        }

        Kirigami.Icon {
            x: arrowMA.x + (arrowMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            source: "go-next"
            color: tile.fg
            isMask: true
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        text: tile.label
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.defaultFont
        maximumLineCount: 1
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }
}
