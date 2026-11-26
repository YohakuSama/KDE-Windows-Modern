import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType
import "../js/trayMetrics.js" as TrayMetrics
import "../components" as Components

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
    readonly property real uiScale: buttonHeight > 0 ? buttonHeight / TrayMetrics.quickToggleHeight : 1
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property bool mirroredLayout: LayoutMirroring.enabled
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

    property color shellAccent: orderView && orderView.shellAccent !== undefined
        ? orderView.shellAccent : Kirigami.Theme.highlightColor
    readonly property color accent: ColorType.accentForSurface(shellAccent, ColorType.quickTileSurface(dark))
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
        border.color: tile.activeFocus ? tile.fg : ColorType.quickTileStroke(tile.dark, tile.active)
        color: ColorType.quickTileFill(tile.dark, tile.active, false, false, tile.accent)

        // Independent Fluent state brushes fill each half continuously.
        // The shared outline and single divider are preserved.
        Rectangle {
            id: toggleBrush
            objectName: "wmQuickTileToggleBrush"
            x: toggleMA.x + (tile.mirroredLayout ? 0 : 1); y: 1
            width: Math.max(0, toggleMA.width - 1)
            height: Math.max(0, bg.height - 2)
            radius: Math.max(0, bg.radius - 1)
            topLeftRadius: tile.mirroredLayout ? 0 : radius
            bottomLeftRadius: topLeftRadius
            topRightRadius: tile.mirroredLayout ? radius : 0
            bottomRightRadius: topRightRadius
            color: ColorType.quickTileFill(tile.dark, tile.active,
                toggleMA.containsMouse, toggleMA.containsPress, tile.accent)
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Rectangle {
            id: detailsBrush
            objectName: "wmQuickTileDetailsBrush"
            x: arrowMA.x + (tile.mirroredLayout ? 1 : 0); y: 1
            width: Math.max(0, arrowMA.width - 1)
            height: Math.max(0, bg.height - 2)
            radius: Math.max(0, bg.radius - 1)
            topLeftRadius: tile.mirroredLayout ? radius : 0
            bottomLeftRadius: topLeftRadius
            topRightRadius: tile.mirroredLayout ? 0 : radius
            bottomRightRadius: topRightRadius
            border.width: arrowMA.activeFocus ? 1 : 0
            border.color: tile.fg
            color: ColorType.quickTileFill(tile.dark, tile.active,
                arrowMA.containsMouse, arrowMA.containsPress, tile.accent)
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
            width: Math.max(0, parent.width - arrowMA.width)
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
            width: TrayMetrics.splitSecondaryWidth(parent.width, tile.uiScale)
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

        Components.NativeGlyph {
            x: toggleMA.x + (toggleMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            objectName: "wmQuickTileGlyph"
            width: Math.max(12, Math.round(16 * tile.uiScale))
            height: width
            roleName: tile.iconSource
            roundToIconSize: false
            opacity: tile.toggleAvailable ? 1 : 0.55
            foreground: tile.active ? ColorType.contrastingForeground(toggleBrush.color) : tile.fg
            isMask: true
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "wmQuickTileDivider"
            x: Math.round(tile.mirroredLayout ? toggleMA.x : arrowMA.x)
            width: 1
            height: parent.height - 4
            color: Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b,
                toggleMA.containsMouse || arrowMA.containsMouse || arrowMA.activeFocus ? 0.20 : 0.07)
        }

        Components.NativeGlyph {
            objectName: "wmQuickTileDetailsGlyph"
            x: arrowMA.x + (arrowMA.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, Math.round(12 * tile.uiScale))
            height: width
            roundToIconSize: false
            roleName: tile.mirroredLayout ? "go-previous-symbolic" : "go-next-symbolic"
            foreground: tile.active ? ColorType.contrastingForeground(detailsBrush.color) : tile.fg
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
