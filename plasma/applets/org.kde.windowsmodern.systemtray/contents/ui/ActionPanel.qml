/*
    Action Panel — Windows 11 Quick Settings, separate from tray overflow.
    Existing KDE toggle/slider backends are preserved.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "components" as Components
import "js/quickSettingsOrder.js" as Order

ColumnLayout {
    id: actionPanel

    signal requestPage(string name)

    readonly property real scale: Plasmoid.configuration.scale / 100

    Layout.fillWidth: true
    spacing: 16 * actionPanel.scale

    // A pre-map size from the hardware/configuration and tile geometry,
    // not visible children. Qt Layout implicitHeight can be zero while
    // the window is hidden. Reserve a complete first viewport in that case.
    readonly property bool brightnessShown: Plasmoid.configuration.showBrightness && brightnessSlider.brightnessAvailable
    readonly property bool volumeShown: Plasmoid.configuration.showVolume && volumeSlider.sinkAvailable
    readonly property int sliderRows: (brightnessShown ? 1 : 0) + (volumeShown ? 1 : 0)
    readonly property int homeHeight: Math.ceil(Math.max(220 * scale,
        12 * scale + Math.max(64 * scale, toggleViewport.viewportHeight)
        + (sliderRows > 0 ? (sliderRows * 36 + (sliderRows - 1) * 12 + 14 + 32) * scale : 16 * scale)
        + 48 * scale))

    // Only this viewport scrolls; the sliders and footer remain fixed.
    function resetScroll() {
        toggleViewport.cancelDrag();
        scrollMotion.stop();
        toggleViewport.cancelFlick();
        toggleViewport.contentY = 0;
    }

    onVisibleChanged: if (!visible && toggleViewport) toggleViewport.cancelDrag()

    // The Flickable has no useful implicitWidth. Do not ask RowLayout
    // to divide space between it and the rail: the rail's controls can
    // take all the width while the three-column grid shrinks to slivers.
    Item {
        id: toggleRow
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(14 * actionPanel.scale)
        Layout.rightMargin: Math.round(14 * actionPanel.scale)
        Layout.topMargin: Math.round(12 * actionPanel.scale)
        implicitHeight: toggleViewport.viewportHeight
        Layout.preferredHeight: implicitHeight
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight
        readonly property int railWidth: Math.round(24 * actionPanel.scale)
        readonly property int railGap: Math.round(4 * actionPanel.scale)

        // Measure the caption independently of visibility. QQuickLayout
        // can report zero implicit size before its window becomes visible.
        PlasmaComponents3.Label {
            id: captionProbe
            visible: false
            text: "Ag"
            font: Kirigami.Theme.defaultFont
        }

        Flickable {
            id: toggleViewport
            anchors.fill: parent
            anchors.rightMargin: hasMoreRows ? toggleRow.railWidth + toggleRow.railGap : 0
            readonly property var tiles: [networkTile, bluetoothTile, airplaneTile, batterySaverTile, nightLightTile, colorSchemeTile, dndTile, micTile, hotspotTile]
            readonly property var knownKeys: tiles.map(tile => tile.orderKey)
            readonly property var availableKeys: tiles.filter(tile => tile.included).map(tile => tile.orderKey)
            readonly property var order: Order.normalizeOrder(
                String(Plasmoid.configuration.quickSettingsOrder || "").split(","), knownKeys)
            readonly property var visibleKeys: Order.visibleOrder(order, availableKeys)
            readonly property int rows: Math.ceil(visibleKeys.length / 3)
            readonly property bool hasMoreRows: rows > 2
            readonly property real rowGap: Math.round(12 * actionPanel.scale)
            readonly property real columnGap: Math.round(6 * actionPanel.scale)
            readonly property real cellWidth: Math.max(1, (width - 2 * columnGap) / 3)
            // Height follows the tallest caption (system font), not the
            // effective visibility or width of a GridLayout parent.
            readonly property real rowHeight: tiles.reduce((largest, tile) =>
                tile.included ? Math.max(largest, tile.implicitHeight) : largest,
                Math.round(48 * actionPanel.scale) + 4 + captionProbe.implicitHeight)
            readonly property real rowStride: rowHeight + rowGap
            readonly property real viewportHeight: Math.max(0, Math.min(2, rows) * rowStride - (rows > 0 ? rowGap : 0))
            readonly property real maxOffset: Math.max(0, contentHeight - height)

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

            function scrollTo(offset) {
                scrollMotion.stop();
                const destination = Order.clampOffset(offset, maxOffset);
                if (Math.abs(destination - contentY) < 1 || Kirigami.Units.shortDuration === 0) {
                    contentY = destination;
                    return;
                }
                scrollMotion.from = contentY;
                scrollMotion.to = destination;
                scrollMotion.start();
            }

            function page(direction) {
                const start = scrollMotion.running ? scrollMotion.to : contentY;
                cancelFlick();
                scrollTo(start + direction * 2 * rowStride);
            }

            function ensureVisible(key) {
                const index = visibleKeys.indexOf(key);
                if (index < 0 || dragKey !== "")
                    return;
                const top = Math.floor(index / 3) * rowStride;
                const bottom = top + rowHeight;
                if (top < contentY)
                    scrollTo(top);
                else if (bottom > contentY + height)
                    scrollTo(bottom - height);
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
                scrollMotion.stop();
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
                scrollTo(Order.snapOffset(contentY, rowStride, maxOffset));
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
                            toggleViewport.scrollTo(Order.snapOffset(toggleViewport.contentY,
                                toggleViewport.rowStride, toggleViewport.maxOffset));
                    });
                }
            }
            onMovementStarted: scrollMotion.stop()
            onMovementEnded: if (!dragKey) scrollTo(Order.snapOffset(contentY, rowStride, maxOffset))

            NumberAnimation {
                id: scrollMotion
                target: toggleViewport
                property: "contentY"
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
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
                    const edge = Math.round(20 * actionPanel.scale);
                    const direction = point.y < edge ? -1
                        : point.y > toggleViewport.height - edge ? 1 : 0;
                    if (direction !== 0) {
                        toggleViewport.contentY = Order.clampOffset(
                            toggleViewport.contentY + direction * 5 * actionPanel.scale,
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
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: true
                    visible: included
                    onArrowClicked: actionPanel.requestPage("network")
                }
                Components.BluetoothToggle {
                    id: bluetoothTile
                    orderKey: "bluetooth"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: available
                    visible: included
                    onArrowClicked: actionPanel.requestPage("bluetooth")
                }
                Components.AirplaneToggle {
                    id: airplaneTile
                    orderKey: "airplane"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showAirplane && available
                    visible: included
                }
                Components.BatterySaverToggle {
                    id: batterySaverTile
                    orderKey: "battery-saver"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showBatterySaver && available
                    visible: included
                    onArrowClicked: actionPanel.requestPage("battery")
                }
                Components.NightLightToggle {
                    id: nightLightTile
                    orderKey: "night-light"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showNightLight && available
                    visible: included
                }
                Components.ColorSchemeToggle {
                    id: colorSchemeTile
                    orderKey: "color-scheme"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showColorScheme
                    visible: included
                }
                Components.DndToggle {
                    id: dndTile
                    orderKey: "dnd"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showDnd
                    visible: included
                }
                Components.MicMuteToggle {
                    id: micTile
                    orderKey: "microphone"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
                    included: Plasmoid.configuration.showMicMute && available
                    visible: included
                }
                Components.HotspotToggle {
                    id: hotspotTile
                    orderKey: "hotspot"
                    orderView: toggleViewport
                    buttonHeight: Math.round(48 * actionPanel.scale)
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

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: rowScrollBar
                parent: scrollTrack
                anchors.fill: parent
                policy: QQC2.ScrollBar.AlwaysOn
                leftPadding: Math.max(0, (width - 4) / 2)
                rightPadding: leftPadding
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: width / 2
                    color: Kirigami.Theme.textColor
                    opacity: rowScrollBar.pressed || rowScrollBar.hovered ? 0.65 : 0.40
                }
                background: Rectangle {
                    width: 2
                    x: (parent.width - width) / 2
                    radius: 1
                    color: Kirigami.Theme.textColor
                    opacity: 0.12
                }
                onPressedChanged: {
                    if (pressed)
                        scrollMotion.stop();
                    else if (!toggleViewport.dragKey)
                        toggleViewport.scrollTo(Order.snapOffset(toggleViewport.contentY,
                            toggleViewport.rowStride, toggleViewport.maxOffset));
                }
            }
        }

        // The rail is reserved from the row count, not scrollbar geometry,
        // avoiding a width -> row height -> visibility feedback loop.
        ColumnLayout {
            id: navigationRail
            visible: toggleViewport.hasMoreRows
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: toggleRow.railWidth
            spacing: 2

            PlasmaComponents3.ToolButton {
                id: previousPageButton
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(20 * actionPanel.scale)
                icon.name: "go-up-symbolic"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: icon.width
                text: i18n("Previous quick settings")
                display: PlasmaComponents3.AbstractButton.IconOnly
                enabled: toggleViewport.contentY > 0.5 && !toggleViewport.dragKey
                onClicked: toggleViewport.page(-1)
                PlasmaComponents3.ToolTip { text: previousPageButton.text }
            }
            Item {
                id: scrollTrack
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 8
            }
            PlasmaComponents3.ToolButton {
                id: nextPageButton
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(20 * actionPanel.scale)
                icon.name: "go-down-symbolic"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: icon.width
                text: i18n("Next quick settings")
                display: PlasmaComponents3.AbstractButton.IconOnly
                enabled: toggleViewport.contentY < toggleViewport.maxOffset - 0.5 && !toggleViewport.dragKey
                onClicked: toggleViewport.page(1)
                PlasmaComponents3.ToolTip { text: nextPageButton.text }
            }
        }
    }

    GridLayout {
        visible: actionPanel.brightnessShown || actionPanel.volumeShown
        Layout.fillWidth: true
        Layout.leftMargin: 14 * actionPanel.scale
        Layout.rightMargin: 14 * actionPanel.scale
        Layout.bottomMargin: 14 * actionPanel.scale
        columns: 3
        rowSpacing: 12 * actionPanel.scale
        columnSpacing: 0

        Components.BrightnessSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            visible: Plasmoid.configuration.showBrightness && brightnessAvailable
            showArrow: true
            panelScreenGeometry: Plasmoid.screenGeometry
            panelScreenIndex: Plasmoid.containment.screen
            onArrowClicked: actionPanel.requestPage("brightness")
        }
        Components.VolumeSlider {
            id: volumeSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            Layout.preferredHeight: Math.round(36 * actionPanel.scale)
            visible: Plasmoid.configuration.showVolume && sinkAvailable
            onArrowClicked: actionPanel.requestPage("volume")
        }
    }

    Components.Footer {
        Layout.fillWidth: true
        Layout.topMargin: -6 * actionPanel.scale
        uiScale: actionPanel.scale
        showBattery: Plasmoid.configuration.showBattery
        onBatteryClicked: actionPanel.requestPage("battery")
    }
}
