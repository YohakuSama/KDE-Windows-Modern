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
    property string accessibleLabel: label
    property string tooltipText: ""
    property bool active: false
    property bool included: true
    property string orderKey: ""
    property Item orderView: null
    property real buttonHeight: -1
    readonly property real uiScale: buttonHeight > 0 ? buttonHeight / 48 : 1
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property int captionHeight: Math.max(Math.round(30 * uiScale), Math.ceil(2 * captionMetrics.lineSpacing))
    FontMetrics { id: captionMetrics; font: caption.font }
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
    Accessible.name: tile.accessibleLabel
    Accessible.checked: tile.active
    Accessible.onPressAction: if (tile.toggleAvailable) tile.clicked()
    Keys.onReturnPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onEnterPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onSpacePressed: if (tile.toggleAvailable) tile.clicked()

    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor, Qt.color(ColorType.cardFill(dark, false)))
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
        color: active ? accent : ColorType.tileFill(tile.dark, false, false)

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
            width: parent.width * 0.5
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
            width: parent.width * 0.5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            onActiveFocusChanged: if (activeFocus && tile.orderView) tile.orderView.ensureVisible(tile.orderKey)
            Accessible.role: Accessible.Button
            Accessible.name: i18n("%1 details", tile.accessibleLabel)
            Accessible.onPressAction: tile.arrowClicked()
            Keys.onReturnPressed: tile.arrowClicked()
            Keys.onEnterPressed: tile.arrowClicked()
            Keys.onSpacePressed: tile.arrowClicked()
            onClicked: tile.arrowClicked()
        }

        Kirigami.Icon {
            x: toggleMA.x + (toggleMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            objectName: "wmQuickTileGlyph"
            width: Math.max(12, Math.round(16 * tile.uiScale))
            height: width
            source: tile.iconSource
            roundToIconSize: false
            opacity: tile.toggleAvailable ? 1 : 0.55
            color: tile.fg
            isMask: true
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(toggleMA.width)
            width: 1
            height: parent.height - 4
            color: Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b,
                toggleMA.containsMouse || arrowMA.containsMouse || arrowMA.activeFocus ? 0.20 : 0.07)
        }

        Kirigami.Icon {
            objectName: "wmQuickTileDetailsGlyph"
            x: arrowMA.x + (arrowMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, Math.round(12 * tile.uiScale))
            height: width
            roundToIconSize: false
            source: "go-next-symbolic"
            color: tile.fg
            isMask: true
        }
    }

    PlasmaComponents3.Label {
        id: caption
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        objectName: "wmQuickTileCaption"
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
