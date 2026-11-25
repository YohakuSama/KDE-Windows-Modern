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
    readonly property real uiScale: buttonHeight > 0 ? buttonHeight / 48 : 1
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property int captionHeight: Math.round(30 * uiScale)
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

    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor, Kirigami.Theme.backgroundColor)
    readonly property color fg: active ? ColorType.contrastingForeground(accent) : Kirigami.Theme.textColor

    spacing: Math.round(8 * uiScale)
    Layout.fillWidth: true
    // Width is supplied by the explicitly sized three-column viewport.
    // A zero preferred-width hint is not a valid tile size.

    Rectangle {
        id: bg
        Layout.fillWidth: true
        objectName: "wmQuickTileSurface"
        Layout.preferredHeight: tile.buttonHeight > 0 ? tile.buttonHeight : width / 2
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        radius: Math.max(3, Math.round(4 * tile.uiScale))
        border.width: 1
        border.color: tile.activeFocus ? tile.fg : active
            ? Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, 0.10)
            : ColorType.tileBorder(tile.dark)
        color: {
            if (active) {
                const alpha = ma.containsPress ? 0.12 : ma.containsMouse ? 0.06 : 0;
                return Qt.tint(accent, Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, alpha));
            }
            return ColorType.tileFill(tile.dark, ma.containsMouse, ma.containsPress);
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
            objectName: "wmQuickTileGlyph"
            width: Math.max(12, Math.round(16 * tile.uiScale))
            height: width
            source: tile.iconSource
            roundToIconSize: false
            color: tile.fg
            isMask: true
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        text: tile.label
        color: Kirigami.Theme.textColor
        Layout.preferredHeight: tile.captionHeight
        Layout.minimumHeight: tile.captionHeight
        Layout.maximumHeight: tile.captionHeight
        font.pixelSize: Math.max(10, Math.round(12 * tile.uiScale))
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        textFormat: Text.PlainText
    }
}
