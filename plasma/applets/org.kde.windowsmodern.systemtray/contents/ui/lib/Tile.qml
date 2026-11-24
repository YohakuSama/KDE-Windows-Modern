import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

ColumnLayout {
    id: tile

    property string iconSource
    property string label
    property string tooltipText: ""
    property bool active: false
    property bool checkable: true
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

    function focusForKeyboard() { forceActiveFocus(Qt.TabFocusReason); }

    onActiveFocusChanged: {
        if (activeFocus && orderView)
            orderView.ensureVisible(orderKey);
    }
    Keys.onPressed: event => {
        if (orderView && orderView.handleTileKey(orderKey, event.key, event.modifiers))
            event.accepted = true;
    }

    signal clicked
    signal rightClicked
    signal middleClicked

    activeFocusOnTab: true

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.checkable: checkable
    Accessible.name: tile.label
    Accessible.checked: tile.active
    Accessible.onPressAction: tile.clicked()
    Keys.onReturnPressed: tile.clicked()
    Keys.onEnterPressed: tile.clicked()
    Keys.onSpacePressed: tile.clicked()

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fg: active ? ColorType.contrastingForeground(accent) : Kirigami.Theme.textColor

    spacing: 4
    Layout.fillWidth: true
    // Width is supplied by the explicitly sized three-column viewport.
    // A zero preferred-width hint is not a valid tile size.

    Rectangle {
        id: bg
        Layout.fillWidth: true
        Layout.preferredHeight: tile.buttonHeight > 0 ? tile.buttonHeight : width / 2
        radius: 4
        border.width: 1
        border.color: tile.activeFocus ? Kirigami.Theme.textColor : active ? "transparent" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        color: {
            if (active) {
                const alpha = ma.containsPress ? 0.12 : ma.containsMouse ? 0.06 : 0;
                return Qt.tint(accent, Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, alpha));
            }
            if (ma.containsPress)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10);
            if (ma.containsMouse)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06);
            return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04);
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
            id: ma
            anchors.fill: parent
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

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: Kirigami.Units.iconSizes.smallMedium
            source: tile.iconSource
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
