/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2026 Nathaniel Krebs <areyoufeelingitnowmrkrebs@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtCore
import org.kde.plasma.plasma5support as Plasma5Support

import org.kde.draganddrop as DnD
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.battery as BatteryBackend
import "js/trayMetrics.js" as TrayMetrics
import "js/popupGeometry.js" as PopupGeometry
import "components" as Components
import "components/volume" as Volume

ContainmentItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool reverseLayout: Plasmoid.configuration.reverseIconOrder
    property Item hoveredQuickSetting: null
    property Item quickSettingsOrigin: null
    readonly property var panelWindow: root.Window.window
    readonly property rect panelGeometry: panelWindow
        ? Qt.rect(panelWindow.x, panelWindow.y, panelWindow.width, panelWindow.height) : Qt.rect(0, 0, 0, 0)
    readonly property real panelExtent: Math.max(0, vertical
        ? (panelGeometry.width || root.width) : (panelGeometry.height || root.height))
    onPanelGeometryChanged: {
        if (dialog && dialog.visible) systemTrayState.expanded = false;
        if (runLoader.item) runLoader.item.close();
    }

    // Debounce native palette changes; reread the effective selection color
    // in the helper. The helper serializes with the appearance mode switch.
    readonly property color nativeAccent: Kirigami.Theme.highlightColor
    readonly property color nativeBackground: Kirigami.Theme.backgroundColor
    readonly property string accentScript: {
        const url = String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "plasma/look-and-feel/org.kde.windowsmodern.dark/contents/scripts/switch-mode.sh"));
        return url.startsWith("file:///") ? decodeURIComponent(url.slice(7))
            : url.startsWith("/") ? url : "";
    }
    property bool accentReady: false
    property bool accentDirty: false
    property string accentCommand: ""

    function scheduleAccentSync() {
        if (!accentReady || accentScript.length === 0) return;
        accentDirty = true;
        accentTimer.restart();
    }

    onNativeAccentChanged: scheduleAccentSync()
    onNativeBackgroundChanged: scheduleAccentSync()

    Timer {
        id: accentTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!root.accentDirty || root.accentCommand.length !== 0) return;
            root.accentDirty = false;
            const script = "'" + root.accentScript.replace(/'/g, "'\\''") + "'";
            root.accentCommand = "bash " + script + " --sync-accent";
            accentExec.connectSource(root.accentCommand);
        }
    }

    Plasma5Support.DataSource {
        id: accentExec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            if (sourceName !== root.accentCommand || data["exit code"] === undefined) return;
            disconnectSource(sourceName);
            root.accentCommand = "";
            if (data["exit code"] !== 0)
                console.warn("Windows Modern accent synchronization failed:", data["stderr"]);
            if (root.accentDirty) accentTimer.restart();
        }
    }

    function panelAnchorForApplet(applet) {
        const revision = tasksGrid.delegateRevision;
        if (applet) {
            for (let i = 0; i < tasksGrid.count; ++i) {
                const cell = tasksGrid.itemAtIndex(i);
                if (cell && cell.item?.applet === applet) return cell;
            }
        }
        return null;
    }

    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : mainLayout.implicitWidth
    Layout.minimumHeight: vertical ? mainLayout.implicitHeight : Kirigami.Units.iconSizes.small

    LayoutMirroring.enabled: !vertical && ((Application.layoutDirection === Qt.RightToLeft) !== reverseLayout)
    LayoutMirroring.childrenInherit: true

    readonly property alias systemTrayState: systemTrayState
    readonly property int itemSize: TrayMetrics.iconSize(vertical ? width : height, Plasmoid.configuration.scaleIconsToFit)
    readonly property int trayCellLength: TrayMetrics.cellLength(itemSize, false, Plasmoid.configuration.iconSpacing)
    readonly property int coreItemSize: TrayMetrics.coreIconSize(vertical ? width : height, Plasmoid.configuration.scaleIconsToFit)
    readonly property int coreNativeRenderSize: TrayMetrics.coreRenderSize(coreItemSize)
    readonly property int systemCellLength: TrayMetrics.coreCellLength(itemSize, coreItemSize, Plasmoid.configuration.iconSpacing)
    BatteryBackend.BatteryControlModel { id: panelBattery }
    Volume.OutputSink { id: panelAudio }
    readonly property var panelAudioSink: panelAudio.sink
    TextMetrics {
        id: batteryPercentMetrics
        text: i18n("%1%", 100)
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: 12
    }
    readonly property bool panelHasBattery: panelBattery.hasCumulative
    readonly property real panelBatteryPercent: panelBattery.percent
    readonly property bool panelBatteryPercentKnown: panelHasBattery
        && Number.isFinite(panelBatteryPercent) && panelBatteryPercent >= 0
    readonly property bool showPanelBatteryPercentage: !vertical
        && Plasmoid.configuration.showBatteryPercentage && panelBatteryPercentKnown
    readonly property int batteryGlyphSize: vertical
        ? Math.max(1, Math.min(coreItemSize, Math.floor(width / 1.25))) : coreItemSize
    readonly property int batteryPercentageWidth: Math.ceil(batteryPercentMetrics.advanceWidth)
    readonly property int batteryContentWidth: panelHasBattery
        ? Math.ceil(batteryGlyphSize * 1.25) + (showPanelBatteryPercentage ? 3 + batteryPercentageWidth : 0)
        : coreItemSize

    readonly property alias visibleLayout: tasksGrid
    readonly property alias hiddenLayout: expandedRepresentation.hiddenLayout
    readonly property bool oneRowOrColumn: true

    readonly property alias hiddenModel: hiddenModel

    Component.onCompleted: {
        // We need all the plasmoiditems to be there for correct working of shortcuts.
        // Instantiators create the plasmoiditems: ensure this is done after
        // this containmentitem actually  exists so they can be immediately parented properly
        // set active and not the model, as this will cause an assert deep in Qt
        activeInstantiator.active = true;
        hiddenInstantiator.active = true;
        Plasmoid.registerClipboardShortcut();
        Plasmoid.registerRunShortcut();
        accentReady = true;
        scheduleAccentSync();
    }

    Connections {
        target: Plasmoid
        function onAccentPreferencesChanged() { root.scheduleAccentSync(); }
        function onActivated() {
            root.quickSettingsOrigin = null;
            systemTrayState.toggleHome(false);
        }
        function onRunDialogRequested() {
            systemTrayState.expanded = false;
            if (runLoader.item) {
                if (runLoader.item.opened)
                    runLoader.item.close();
                else
                    runLoader.item.open(Plasmoid.runDialogArea(root));
            } else {
                runLoader.active = true;
            }
        }
        function onClipboardHistoryRequested() {
            const applet = Plasmoid.appletForPluginId("org.kde.plasma.clipboard");
            if (!applet) return;
            if (systemTrayState.expanded && systemTrayState.activeApplet === applet) {
                systemTrayState.expanded = false;
                return;
            }
            systemTrayState.setActiveApplet(applet, undefined, "panel");
        }
    }

    // Allocate the window only when the user first invokes Win+R.
    Loader {
        id: runLoader
        active: false
        sourceComponent: Components.RunDialog { commandRunner: Plasmoid }
        onLoaded: item.open(Plasmoid.runDialogArea(root))
    }

    KItemModels.KSortFilterProxyModel {
        id: activeModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => {
            let value = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
            return value === PlasmaCore.Types.ActiveStatus;
        }
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel // avoid unnecessary binding, it causes loops
    }

    KItemModels.KSortFilterProxyModel {
        id: hiddenModel
        filterRoleName: "effectiveStatus"
        filterRowCallback: (sourceRow, sourceParent) => {
            let value = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), filterRole);
            return value === PlasmaCore.Types.PassiveStatus
        }
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel // avoid unnecessary binding, it causes loops
    }

    Instantiator {
        id: hiddenInstantiator
        // It's important that those are inactive at creation time
        // to not create plasmoiditems too soon
        active: false
        model: hiddenModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row, "overflow")
                }
            }
        }
    }

    Instantiator {
        id: activeInstantiator
        active: false
        model:activeModel
        delegate: Connections {
            required property QtObject applet
            required property int row
            target: applet
            function onExpandedChanged(expanded: bool) {
                if (expanded) {
                    systemTrayState.setActiveApplet(applet, row, "panel")
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        onWheel: wheel => {
            // Don't propagate unhandled wheel events
            wheel.accepted = true;
        }

        SystemTrayState {
            id: systemTrayState
            popupVisible: dialog.visible
        }

        CurrentItemHighLight {
            location: Plasmoid.location
            parent: root
        }

        DnD.DropArea {
            anchors.fill: parent

            preventStealing: true

            /** Extracts the name of the system tray applet in the drag data if present
            * otherwise returns null*/
            function systemTrayAppletName(event) {
                if (event.mimeData.formats.indexOf("text/x-plasmoidservicename") < 0) {
                    return null;
                }
                const plasmoidId = event.mimeData.getDataAsByteArray("text/x-plasmoidservicename");

                if (!Plasmoid.isSystemTrayApplet(plasmoidId)) {
                    return null;
                }
                return plasmoidId;
            }

            onDragEnter: event => {
                if (!systemTrayAppletName(event)) {
                    event.ignore();
                }
            }

            onDrop: event => {
                const plasmoidId = systemTrayAppletName(event);
                if (!plasmoidId) {
                    event.ignore();
                    return;
                }

                if (Plasmoid.configuration.extraItems.indexOf(plasmoidId) < 0) {
                    const extraItems = Plasmoid.configuration.extraItems;
                    extraItems.push(plasmoidId);
                    Plasmoid.configuration.extraItems = extraItems;
                }
            }
        }


        // Draw one rounded background per contiguous run of real system
        // cells, behind the delegates. No independently rounded hover tiles.
        // Use actual layout geometry, not model indices or guessed margins.
        Item {
            id: quickSettingsHighlight
            objectName: "wmQuickSettingsHighlight"
            anchors.fill: parent
            z: -1
            visible: root.hoveredQuickSetting !== null || systemTrayState.quickSettingsOpen
            readonly property var runs: {
                const revision = tasksGrid.delegateRevision;
                const cells = [];
                for (let i = 0; i < tasksGrid.count; ++i) {
                    const item = tasksGrid.itemAtIndex(i);
                    if (!item) continue;
                    cells.push({
                        systemGroup: item.item ? !!item.item.groupedQuickSettings : item.systemGroup,
                        x: mainLayout.x + tasksGrid.x + item.x,
                        y: mainLayout.y + tasksGrid.y + item.y,
                        width: item.width, height: item.height
                    });
                }
                return TrayMetrics.groupRects(cells, root.vertical);
            }
            Repeater {
                model: quickSettingsHighlight.runs
                delegate: Rectangle {
                    required property var modelData
                    objectName: "wmQuickSettingsGroupBackground"
                    readonly property var hoverRect: TrayMetrics.groupHoverRect(modelData, root.panelExtent, root.vertical)
                    x: hoverRect.x
                    y: hoverRect.y
                    width: hoverRect.width
                    height: hoverRect.height
                    radius: 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.08)
                }
            }
        }

        // Invisible-to-input item with the exact geometry of the system
        // button group, not the entire tray (which may include many icons).
        Item {
            id: quickSettingsAnchor
            readonly property var run: {
                const runs = quickSettingsHighlight.runs;
                const origin = root.quickSettingsOrigin;
                const point = origin ? origin.mapToItem(root, origin.width / 2, origin.height / 2) : null;
                return TrayMetrics.anchorRun(runs, point, root.vertical,
                    !root.vertical && root.LayoutMirroring.enabled);
            }
            x: run ? run.x : 0
            y: run ? run.y : 0
            width: run ? run.width : root.width
            height: run ? run.height : root.height
        }

        //Main Layout
        GridLayout {
            id: mainLayout

            rowSpacing: 0
            columnSpacing: 0
            anchors.fill: parent

            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight

            // A tray contains a small finite list of live applets. Repeater
            // preserves every delegate while a one-row layout allows the
            // Windows system group to use narrower cells than third-party SNI.
            GridLayout {
                id: tasksGrid

                Layout.row: root.vertical && !root.reverseLayout ? 1 : 0
                Layout.column: root.vertical ? 0 : 1
                Layout.alignment: Qt.AlignCenter
                rows: root.vertical ? Math.max(1, trayItems.count) : 1
                columns: root.vertical ? 1 : Math.max(1, trayItems.count)
                rowSpacing: 0
                columnSpacing: 0

                readonly property int count: trayItems.count
                property int delegateRevision: 0
                readonly property int rowsOrColumns: 1
                readonly property int itemSize: root.itemSize
                function itemAtIndex(index) {
                    return index >= 0 && index < trayItems.count ? trayItems.itemAt(index) : null;
                }

                Repeater {
                    id: trayItems
                    model: activeModel
                    onItemAdded: (index, item) => tasksGrid.delegateRevision++
                    onItemRemoved: (index, item) => tasksGrid.delegateRevision++

                    delegate: ItemLoader {
                        id: delegate

                        readonly property string loadedItemId: item?.itemId || model.itemId || ""
                        readonly property bool systemGroup: TrayMetrics.isQuickSettings(loadedItemId)
                        readonly property bool batteryCell: loadedItemId === "org.kde.plasma.battery"
                        readonly property int contentLength: batteryCell && !root.vertical
                            ? root.batteryContentWidth : root.coreItemSize
                        readonly property int baseSystemCellLength: batteryCell && !root.vertical
                            ? Math.max(root.systemCellLength, TrayMetrics.paddedCoreContentLength(contentLength))
                            : root.systemCellLength
                        leadingSystemInset: {
                            const revision = tasksGrid.delegateRevision;
                            const previous = tasksGrid.itemAtIndex(index - 1);
                            return TrayMetrics.systemEdgeInset(systemGroup,
                                !!previous && previous.systemGroup, baseSystemCellLength, contentLength);
                        }
                        trailingSystemInset: {
                            const revision = tasksGrid.delegateRevision;
                            const next = tasksGrid.itemAtIndex(index + 1);
                            return TrayMetrics.systemEdgeInset(systemGroup,
                                !!next && next.systemGroup, baseSystemCellLength, contentLength);
                        }
                        readonly property int cellLength: systemGroup
                            ? leadingSystemInset + baseSystemCellLength + trailingSystemInset
                            : root.trayCellLength
                        readonly property int positionIndex: TrayMetrics.visualIndex(index, trayItems.count,
                            root.vertical, root.reverseLayout)

                        Layout.row: root.vertical ? positionIndex : 0
                        Layout.column: root.vertical ? 0 : positionIndex
                        Layout.preferredWidth: root.vertical ? root.width : cellLength
                        Layout.preferredHeight: root.vertical ? cellLength : root.height
                        Layout.minimumWidth: Layout.preferredWidth
                        Layout.maximumWidth: Layout.preferredWidth
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight

                        // Preserve native keyboard stacking after model changes.
                        Component.onCompleted: {
                            const previous = tasksGrid.itemAtIndex(index - 1);
                            if (previous) {
                                Plasmoid.stackItemBefore(delegate, previous);
                            } else {
                                const next = tasksGrid.itemAtIndex(index + 1);
                                if (next)
                                    Plasmoid.stackItemAfter(delegate, next);
                            }
                        }
                    }
                }
            }

            ExpanderArrow {
                id: expander

                Layout.row: root.vertical && root.reverseLayout ? 1 : 0
                Layout.column: 0

                Layout.fillWidth: vertical
                Layout.fillHeight: !vertical
                Layout.alignment: vertical ? Qt.AlignVCenter : Qt.AlignHCenter
                iconSize: Math.min(16, root.itemSize)
                cellLength: root.trayCellLength
                visible: root.hiddenLayout.itemCount > 0
                onVisibleChanged: {
                    if (!visible && systemTrayState.overflowOpen)
                        systemTrayState.expanded = false;
                }
            }
        }

        Timer {
            id: expandedSync
            interval: 100
            onTriggered: if (!dialog.visible) systemTrayState.expanded = false;
        }

        // Dialog's default property is its single QQuickItem mainItem.
        // Nonvisual helpers belong to the owning item, not that property.
        Connections {
            target: systemTrayState
            function onExpandedChanged() { dialog.openForState(); }
        }
        Timer {
            id: geometryProbe
            interval: 180
            repeat: true
            property int attempts: 0
            onTriggered: {
                if (!dialog.visible) { stop(); return; }
                attempts++;
                const ok = Math.abs(dialog.width - dialog.wantedWidth) <= 2
                    && Math.abs(dialog.height - dialog.wantedHeight) <= 2
                    && expandedRepresentation.height >= expandedRepresentation.popupHeight - 2;
                if (ok || attempts >= 3) {
                    console.info("WM_POPUP tray", ok ? "OK" : "SIZE_MISMATCH",
                        dialog.width, dialog.height, expandedRepresentation.width,
                        expandedRepresentation.height, "expected", dialog.wantedWidth, dialog.wantedHeight);
                    stop();
                }
            }
        }

        // Anchor to the selected tray item, but measure the perpendicular
        // gap from the actual panel edge, just like Start and the clock.
        Item {
            id: trayPopupAnchor
            readonly property Item target: systemTrayState.overflowMode && expander.visible ? expander
                : systemTrayState.quickSettingsRoute || !systemTrayState.activeApplet ? quickSettingsAnchor
                : root.panelAnchorForApplet(systemTrayState.activeApplet) || quickSettingsAnchor
            parent: target || root
            width: target ? target.width : 0
            height: target ? target.height : 0

            function sync() {
                if (!target || !target.Window.window) return;
                const edge = Plasmoid.location === PlasmaCore.Types.BottomEdge ? "bottom"
                    : Plasmoid.location === PlasmaCore.Types.TopEdge ? "top"
                    : Plasmoid.location === PlasmaCore.Types.LeftEdge ? "left"
                    : Plasmoid.location === PlasmaCore.Types.RightEdge ? "right" : "";
                const pos = target.mapToGlobal(0, 0);
                const offset = PopupGeometry.normalOffset(edge, root.panelGeometry,
                    {x: pos.x, y: pos.y, width: target.width, height: target.height});
                x = offset.x;
                y = offset.y;
            }
            onTargetChanged: Qt.callLater(sync)
        }

        // One shell-role popup, with independent card surfaces when a
        // media session is present. Dialog.NoBackground lets the actual
        // desktop remain visible between cards; no second focus window.
        PlasmaCore.Dialog {
            id: dialog
            objectName: "popupWindow"
            type: PlasmaCore.Dialog.AppletPopup
            flags: Qt.Dialog
            visualParent: trayPopupAnchor
            location: Plasmoid.location
            floating: PopupGeometry.popupGap()
            // The native tray coordinates focus with Start/Search and clock.
            readonly property bool coordinatedPopup: typeof Plasmoid.prepareShellPopup === "function"
            hideOnWindowDeactivate: !coordinatedPopup && !Plasmoid.configuration.pin
            property bool wmKeepOnDeactivate: Plasmoid.configuration.pin
            visible: false
            function closeCoordinatedPopup() {
                systemTrayState.expanded = false;
            }

            // Dialog owns screen placement and frame margins. Explicit
            // content sizes are supplied by the representation itself.
            readonly property int wantedWidth: Math.ceil(expandedRepresentation.popupWidth + margins.left + margins.right)
            readonly property int wantedHeight: Math.ceil(expandedRepresentation.popupHeight + margins.top + margins.bottom)
            function openForState() {
                if (systemTrayState.expanded) {
                    if (!visualParent || !visualParent.Window.window || !visualParent.visible
                            || visualParent.width <= 0 || visualParent.height <= 0) {
                        systemTrayState.expanded = false;
                        return;
                    }
                    trayPopupAnchor.sync();
                    expandedSync.stop();
                    if (coordinatedPopup)
                        Plasmoid.prepareShellPopup("tray", dialog);
                    visible = true;
                    geometryProbe.attempts = 0;
                    geometryProbe.restart();
                } else {
                    visible = false;
                }
            }

            backgroundHints: expandedRepresentation.customCard ? PlasmaCore.Dialog.NoBackground
                : (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground)
                    ? PlasmaCore.Dialog.SolidBackground : PlasmaCore.Dialog.StandardBackground

            onVisibleChanged: {
                if (!visible) {
                    if (expandedRepresentation) {
                        expandedRepresentation.resetQuickSettings();
                        expandedRepresentation.scheduleSplitBlur();
                    }
                    expandedSync.restart();
                } else {
                    expandedSync.stop();
                    dialog.requestActivate();
                    Qt.callLater(expandedRepresentation.focusCurrentPage);
                    Qt.callLater(expandedRepresentation.scheduleSplitBlur);
                }
            }
            mainItem: ExpandedRepresentation {
                id: expandedRepresentation
                width: implicitWidth
                height: implicitHeight

                Keys.onEscapePressed: event => {
                    systemTrayState.expanded = false;
                    if (typeof Plasmoid.restoreShellPopupFocus === "function")
                        Plasmoid.restoreShellPopupFocus();
                    event.accepted = true;
                }

                // Being there forces the items to fully load, and they will be reparented in the stack one by one, this item is *never* visible
                // it's important this item is parented to the popup, otherwise the full representation will be reparented every time the popup opens or closes
                Item {
                    id: preloadedStorage
                    visible: false
                }

                LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
                LayoutMirroring.childrenInherit: true
            }
        }
    }
}
