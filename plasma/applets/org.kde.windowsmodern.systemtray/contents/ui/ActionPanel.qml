/*
    Action Panel — Windows 11 Quick Settings, separate from tray overflow.
    Existing KDE toggle/slider backends are preserved.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "components" as Components
import "lib" as Lib
import "js/quickSettingsOrder.js" as Order
import "js/colorType.js" as ColorType

ColumnLayout {
    id: actionPanel

    signal requestPage(string name)

    property real uiScale: Plasmoid.configuration.scale / 100

    // Outer spacing includes the native KSVG dialog frame when present.
    // The separated media window has no native frame and supplies the
    // same total spacing itself.
    property real frameInset: 0
    readonly property int edgeInset: Math.round(24 * uiScale)
    readonly property int contentInset: Math.max(0, edgeInset - Math.round(frameInset))
    readonly property int gridBottomGap: Math.round(14 * uiScale)
    readonly property int sliderInset: Math.round(16 * uiScale)
    readonly property int sliderHorizontalInset: Math.max(0, Math.round(18 * uiScale) - Math.round(frameInset))
    readonly property int sliderGap: Math.round(12 * uiScale)
    readonly property int sliderHeight: Math.max(28, Math.round(36 * uiScale))
    readonly property int footerHeight: Math.max(24, Math.round(48 * uiScale) - Math.round(frameInset))
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)

    Layout.fillWidth: true
    spacing: 0

    // A pre-map size from the hardware/configuration and tile geometry,
    // not visible children. Qt Layout implicitHeight can be zero while
    // the window is hidden. Reserve a complete first viewport in that case.
    readonly property bool brightnessShown: Plasmoid.configuration.showBrightness && brightnessSlider.brightnessAvailable
    readonly property bool volumeShown: Plasmoid.configuration.showVolume && volumeSlider.sinkAvailable
    readonly property int sliderRows: (brightnessShown ? 1 : 0) + (volumeShown ? 1 : 0)
    readonly property int nominalHomeHeight: Math.ceil(Math.max(220 * uiScale,
        edgeInset + Math.max(64 * uiScale, toggleViewport.viewportHeight) + gridBottomGap
        + (sliderRows > 0 ? 1 + 2 * sliderInset + sliderRows * sliderHeight
            + (sliderRows - 1) * sliderGap : 0)
        + Math.round(48 * uiScale)))
    readonly property int homeHeight: Math.max(1, nominalHomeHeight - 2 * Math.round(frameInset))

    // Only this viewport scrolls; the sliders and footer remain fixed.
    function resetScroll() {
        toggleViewport.cancelDrag();
        toggleViewport.cancelFlick();
        toggleViewport.contentY = 0;
    }

    onVisibleChanged: if (!visible && toggleViewport) toggleViewport.cancelDrag()

    // The 26H2 reference has page dots and a single directional arrow
    // only when more than two rows are available. No idle scrollbar rail.
    Item {
        id: toggleRow
        Layout.fillWidth: true
        objectName: "wmQuickSettingsTileRow"
        Layout.leftMargin: actionPanel.contentInset
        Layout.rightMargin: actionPanel.contentInset
        Layout.topMargin: actionPanel.contentInset
        Layout.bottomMargin: actionPanel.gridBottomGap
        implicitHeight: Math.max(Math.round(64 * actionPanel.uiScale), toggleViewport.viewportHeight)
        Layout.preferredHeight: implicitHeight
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight

        Flickable {
            id: toggleViewport
            anchors.fill: parent
            objectName: "wmQuickSettingsGridViewport"
            readonly property var tiles: [networkTile, bluetoothTile, airplaneTile, batterySaverTile, nightLightTile, colorSchemeTile, micTile, hotspotTile, castTile, accessibilityTile]
            readonly property var knownKeys: tiles.map(tile => tile.orderKey)
            readonly property var availableKeys: tiles.filter(tile => tile.included).map(tile => tile.orderKey)
            readonly property var order: Order.normalizeOrder(
                String(Plasmoid.configuration.quickSettingsOrder || "").split(","), knownKeys)
            readonly property var visibleKeys: Order.visibleOrder(order, availableKeys)
            readonly property int rows: Math.ceil(visibleKeys.length / 3)
            readonly property bool hasMoreRows: rows > 2
            readonly property real rowGap: Math.round(12 * actionPanel.uiScale)
            readonly property real columnGap: Math.round(14 * actionPanel.uiScale)
            readonly property real cellWidth: Math.max(1, (width - 2 * columnGap) / 3)
            // Two caption lines are reserved for every tile, keeping
            // the second row aligned even for a long device name.
            readonly property real rowHeight: Math.round(48 * actionPanel.uiScale)
                + Math.round(8 * actionPanel.uiScale) + Math.round(30 * actionPanel.uiScale)
            readonly property real rowStride: rowHeight + rowGap
            readonly property real viewportHeight: Math.max(0, Math.min(2, rows) * rowStride - (rows > 0 ? rowGap : 0))
            readonly property real maxOffset: Math.max(0, contentHeight - height)
            readonly property int pageCount: Math.max(1, Math.ceil(rows / 2))
            readonly property int currentPage: maxOffset > 0 ? Math.round(contentY / maxOffset * (pageCount - 1)) : 0

            property string dragKey: ""
            property int dropIndex: -1
            property point dragStart: Qt.point(0, 0)
            property point pointerPosition: Qt.point(0, 0)
            property real dragStartOffset: 0
            readonly property real dragOffsetX: pointerPosition.x - dragStart.x
            readonly property real dragOffsetY: pointerPosition.y - dragStart.y + contentY - dragStartOffset
            property bool ready: false

            contentWidth: width
            contentHeight: tileGrid.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            pixelAligned: true
            interactive: hasMoreRows && dragKey === ""

            // Mouse drags belong to tile reordering; wheel, touchpad and
            // touchscreen gestures still scroll. Qt 6.9 added this property.
            Component.onCompleted: {
                if ("acceptedButtons" in toggleViewport)
                    toggleViewport.acceptedButtons = Qt.NoButton;
                ready = true;
            }

            function tileForKey(key) {
                return tiles.find(tile => tile.orderKey === key) || null;
            }

            function setOffsetImmediately(offset) {
                cancelFlick();
                contentY = Order.clampOffset(offset, maxOffset);
            }

            function settleRows() {
                if (dragKey !== "" || moving || flicking) return;
                const next = Order.snapOffset(contentY, rowStride, maxOffset);
                if (Math.abs(next - contentY) > 0.5) setOffsetImmediately(next);
            }
            function page(direction) {
                showPage(Math.max(0, Math.min(pageCount - 1, currentPage + direction)));
            }

            function showPage(index) {
                setOffsetImmediately(Order.snapOffset(pageCount > 1
                    ? index * maxOffset / (pageCount - 1) : 0, rowStride, maxOffset));
            }

            // WheelHandler can move contentY without emitting movementEnded.
            // Settle after the last delta, without interfering with drag/reorder.
            onContentYChanged: if (ready && dragKey === "") rowSettle.restart()
            onMovementEnded: settleRows()
            Timer {
                id: rowSettle
                interval: 120
                onTriggered: toggleViewport.settleRows()
            }

            // The same native wheel event filter used by Plasma Kickoff.
            // It handles both the grid and the attached vertical scrollbar,
            // including angle/pixel delta conversion on Wayland.
            Kirigami.WheelHandler {
                target: toggleViewport.hasMoreRows && toggleViewport.dragKey === ""
                    ? toggleViewport : null
                filterMouseEvents: true
                blockTargetWheel: true
                keyNavigationEnabled: false
                verticalStepSize: Math.max(1, toggleViewport.rowStride)
            }

            function ensureVisible(key) {
                const index = visibleKeys.indexOf(key);
                if (index < 0 || dragKey !== "")
                    return;
                const top = Math.floor(index / 3) * rowStride;
                const bottom = top + rowHeight;
                if (top < contentY)
                    setOffsetImmediately(top);
                else if (bottom > contentY + height)
                    setOffsetImmediately(bottom - height);
            }

            function saveMove(key, to) {
                const next = Order.moveVisible(order, availableKeys, key, to);
                if (next.join(",") !== order.join(","))
                    Plasmoid.configuration.quickSettingsOrder = next.join(",");
            }

            function handleTileKey(key, pressedKey, modifiers) {
                const from = visibleKeys.indexOf(key);
                let delta = 0;
                switch (pressedKey) {
                case Qt.Key_Left: delta = -1; break;
                case Qt.Key_Right: delta = 1; break;
                case Qt.Key_Up: delta = -3; break;
                case Qt.Key_Down: delta = 3; break;
                case Qt.Key_PageUp: page(-1); return true;
                case Qt.Key_PageDown: page(1); return true;
                default: return false;
                }
                const to = from + delta;
                if (from < 0 || to < 0 || to >= visibleKeys.length)
                    return false;
                if (modifiers & Qt.ControlModifier) {
                    saveMove(key, to);
                    Qt.callLater(() => ensureVisible(key));
                } else {
                    const next = tileForKey(visibleKeys[to]);
                    if (next)
                        next.focusForKeyboard();
                }
                return true;
            }

            function beginDrag(key, position) {
                if (dragKey !== "" || visibleKeys.indexOf(key) < 0)
                    return;
                dragStart = position;
                pointerPosition = position;
                dragStartOffset = contentY;
                dropIndex = visibleKeys.indexOf(key);
                dragKey = key;
                cancelFlick();
            }

            function updateDrag(key, position) {
                if (dragKey !== key)
                    return;
                pointerPosition = position;
                dropIndex = position.y >= 0 && position.y < height
                    ? Order.slotAt(position.x, position.y + contentY, width, rowStride, visibleKeys.length) : -1;
            }

            function finishDrag(key, position) {
                if (dragKey !== key)
                    return;
                updateDrag(key, position);
                const destination = dropIndex;
                cancelDrag();
                if (destination >= 0)
                    saveMove(key, destination);
                setOffsetImmediately(contentY);
            }

            function cancelDrag(key) {
                if (key !== undefined && dragKey !== key)
                    return;
                dragKey = "";
                dropIndex = -1;
            }

            onVisibleKeysChanged: {
                if (ready) {
                    cancelDrag();
                    Qt.callLater(() => {
                        if (!toggleViewport.dragKey)
                            toggleViewport.setOffsetImmediately(toggleViewport.contentY);
                    });
                }
            }
            // Dragging near the edge reaches later rows without requiring
            // the user to drop the tile and scroll separately.
            Timer {
                interval: 30
                repeat: true
                running: toggleViewport.dragKey !== "" && toggleViewport.hasMoreRows
                onTriggered: {
                    const point = toggleViewport.pointerPosition;
                    if (point.x < 0 || point.x >= toggleViewport.width
                            || point.y < 0 || point.y >= toggleViewport.height)
                        return;
                    const edge = Math.round(20 * actionPanel.uiScale);
                    const direction = point.y < edge ? -1
                        : point.y > toggleViewport.height - edge ? 1 : 0;
                    if (direction !== 0) {
                        toggleViewport.contentY = Order.clampOffset(
                            toggleViewport.contentY + direction * 5 * actionPanel.uiScale,
                            toggleViewport.maxOffset);
                        toggleViewport.updateDrag(toggleViewport.dragKey, point);
                    }
                }
            }

            Item {
                id: tileGrid
                width: toggleViewport.width
                height: Math.max(0, toggleViewport.rows * toggleViewport.rowStride
                    - (toggleViewport.rows > 0 ? toggleViewport.rowGap : 0))
                Components.NetworkToggle {
                    id: networkTile
                    orderKey: "network"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: true
                    visible: included
                    onArrowClicked: actionPanel.requestPage("network")
                }
                Components.BluetoothToggle {
                    id: bluetoothTile
                    orderKey: "bluetooth"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: available
                    visible: included
                    onArrowClicked: actionPanel.requestPage("bluetooth")
                }
                Components.AirplaneToggle {
                    id: airplaneTile
                    orderKey: "airplane"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showAirplane && available
                    visible: included
                }
                Components.BatterySaverToggle {
                    id: batterySaverTile
                    orderKey: "battery-saver"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showBatterySaver && available
                    visible: included
                    onRightClicked: actionPanel.requestPage("battery")
                }
                Components.NightLightToggle {
                    id: nightLightTile
                    orderKey: "night-light"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showNightLight && available
                    visible: included
                }
                Components.ColorSchemeToggle {
                    id: colorSchemeTile
                    orderKey: "color-scheme"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showColorScheme
                    visible: included
                }
                Components.MicMuteToggle {
                    id: micTile
                    orderKey: "microphone"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showMicMute && available
                    visible: included
                }
                Lib.Tile {
                    id: castTile
                    orderKey: "cast"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.castAvailable
                    checkable: false
                    label: i18n("Cast")
                    iconSource: "video-display"
                    onClicked: Plasmoid.openCast()
                }
                Lib.Tile {
                    id: accessibilityTile
                    orderKey: "accessibility"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    checkable: false
                    included: Plasmoid.accessibilityAvailable
                    label: i18n("Accessibility")
                    iconSource: "preferences-desktop-accessibility"
                    onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_access")
                }
                Components.HotspotToggle {
                    id: hotspotTile
                    orderKey: "hotspot"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.uiScale)
                    included: Plasmoid.configuration.showHotspot && (hotspotSupported || hotspotActive)
                    visible: included
                }
            }

            Rectangle {
                readonly property Item destination: toggleViewport.dropIndex >= 0
                    ? toggleViewport.tileForKey(toggleViewport.visibleKeys[toggleViewport.dropIndex]) : null
                visible: toggleViewport.dragKey !== "" && destination !== null
                    && destination.orderKey !== toggleViewport.dragKey
                x: destination ? destination.x : 0
                y: destination ? destination.y : 0
                width: destination ? destination.width : 0
                height: destination ? destination.buttonHeight : 0
                radius: 4
                color: "transparent"
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
                z: 1
            }


        }

        Column {
            id: pageControls
            objectName: "wmQuickSettingsPageControls"
            visible: toggleViewport.hasMoreRows
            // Use the existing right gutter, not part of a tile column.
            width: Math.round(14 * actionPanel.uiScale)
            anchors.left: parent.right
            anchors.leftMargin: Math.round(1 * actionPanel.uiScale)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * actionPanel.uiScale)

            Repeater {
                model: toggleViewport.pageCount
                delegate: Item {
                    id: pageDot
                    required property int index
                    width: pageControls.width
                    height: Math.round(12 * actionPanel.uiScale)
                    Accessible.role: Accessible.Button
                    Accessible.name: i18n("Page %1", index + 1)
                    Accessible.onPressAction: toggleViewport.showPage(index)
                    activeFocusOnTab: true
                    Keys.onReturnPressed: toggleViewport.showPage(index)
                    Keys.onSpacePressed: toggleViewport.showPage(index)
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round((toggleViewport.currentPage === pageDot.index ? 5 : 3) * actionPanel.uiScale)
                        height: width
                        radius: width / 2
                        color: actionPanel.dark ? "#CCCCCC" : "#737373"
                        opacity: toggleViewport.currentPage === pageDot.index || pageDot.activeFocus ? 1 : 0.55
                    }
                    MouseArea { anchors.fill: parent; onClicked: toggleViewport.showPage(pageDot.index) }
                }
            }

            Item {
                id: pageArrow
                width: pageControls.width
                height: Math.round(16 * actionPanel.uiScale)
                readonly property bool atEnd: toggleViewport.contentY >= toggleViewport.maxOffset - 1
                function navigate() { toggleViewport.page(atEnd ? -1 : 1); }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: atEnd ? i18n("Previous page") : i18n("Next page")
                Accessible.onPressAction: navigate()
                Keys.onReturnPressed: navigate()
                Keys.onSpacePressed: navigate()
                Canvas {
                    id: pageTriangle
                    anchors.centerIn: parent
                    width: Math.max(8, Math.round(10 * actionPanel.uiScale))
                    height: width
                    readonly property bool up: pageArrow.atEnd
                    readonly property color ink: actionPanel.dark ? "#CCCCCC" : "#737373"
                    onUpChanged: requestPaint()
                    onInkChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.clearRect(0, 0, width, height);
                        c.fillStyle = ink;
                        c.beginPath();
                        c.moveTo(width * 0.13, height * (up ? 0.70 : 0.30));
                        c.lineTo(width * 0.87, height * (up ? 0.70 : 0.30));
                        c.lineTo(width * 0.50, height * (up ? 0.26 : 0.74));
                        c.closePath();
                        c.fill();
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: pageArrow.navigate() }
            }
        }
    }

    Rectangle {
        objectName: "wmQuickSettingsSliderDivider"
        visible: actionPanel.sliderRows > 0
        Layout.fillWidth: true
        Layout.leftMargin: -actionPanel.frameInset + 1
        Layout.rightMargin: -actionPanel.frameInset + 1
        Layout.preferredHeight: 1
        color: ColorType.divider(actionPanel.dark)
    }

    GridLayout {
        visible: actionPanel.sliderRows > 0
        Layout.fillWidth: true
        Layout.leftMargin: actionPanel.sliderHorizontalInset
        Layout.rightMargin: actionPanel.sliderHorizontalInset
        Layout.topMargin: actionPanel.sliderInset
        Layout.bottomMargin: actionPanel.sliderInset
        columns: 3
        rowSpacing: actionPanel.sliderGap
        columnSpacing: 0

        Components.BrightnessSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            visible: Plasmoid.configuration.showBrightness && brightnessAvailable
            showArrow: false
            reserveDetailsSpace: true
            Layout.preferredHeight: actionPanel.sliderHeight
            implicitHeight: actionPanel.sliderHeight
            panelScreenGeometry: Plasmoid.screenGeometry
            panelScreenIndex: Plasmoid.containment.screen
            onRightClicked: actionPanel.requestPage("brightness")
        }
        Components.VolumeSlider {
            id: volumeSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            Layout.preferredHeight: actionPanel.sliderHeight
            implicitHeight: actionPanel.sliderHeight
            visible: Plasmoid.configuration.showVolume && sinkAvailable
            reserveDetailsSpace: true
            onArrowClicked: actionPanel.requestPage("volume")
        }
    }

    Components.Footer {
        Layout.fillWidth: true
        Layout.preferredHeight: actionPanel.footerHeight
        Layout.minimumHeight: actionPanel.footerHeight
        Layout.maximumHeight: actionPanel.footerHeight
        frameInset: actionPanel.frameInset
        uiScale: actionPanel.uiScale
        showBattery: Plasmoid.configuration.showBattery
        onBatteryClicked: actionPanel.requestPage("battery")
    }
}
