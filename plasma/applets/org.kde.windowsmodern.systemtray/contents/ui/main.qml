/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2026 Nathaniel Krebs <areyoufeelingitnowmrkrebs@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.draganddrop as DnD
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "js/trayMetrics.js" as TrayMetrics

ContainmentItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool reverseLayout: Plasmoid.configuration.reverseIconOrder
    property Item hoveredQuickSetting: null

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
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            systemTrayState.toggleHome(false);
        }
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
                    systemTrayState.setActiveApplet(applet, row)
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
                    systemTrayState.setActiveApplet(applet, row)
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
                readonly property int rowsOrColumns: 1
                readonly property int itemSize: root.itemSize
                function itemAtIndex(index) {
                    return index >= 0 && index < trayItems.count ? trayItems.itemAt(index) : null;
                }

                Repeater {
                    id: trayItems
                    model: activeModel

                    delegate: ItemLoader {
                        id: delegate

                        readonly property bool systemGroup: TrayMetrics.isQuickSettings(model.itemId)
                        readonly property int cellLength: systemGroup ? root.systemCellLength : root.trayCellLength
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

        //Main popup
        PlasmaCore.AppletPopup {
            id: dialog
            objectName: "popupWindow"
            visualParent: systemTrayState.overflowMode && expander.visible ? expander : root
            popupDirection: switch (Plasmoid.location) {
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge
                default:
                    return Qt.TopEdge
            }
            // Keep a visible gap and native rounded frames on docked panels.
            margin: Math.max(Math.round(8 * Plasmoid.configuration.scale / 100),
                (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersFloatingApplets)
                    ? Kirigami.Units.largeSpacing : 0)

            Behavior on margin {
                NumberAnimation {
                    // Since the panel animation won't be perfectly in sync,
                    // using a duration larger than the panel animation results
                    // in a better-looking animation.
                    duration: Kirigami.Units.veryLongDuration
                    easing.type: Easing.OutCubic
                }
            }

            floating: Plasmoid.location == PlasmaCore.Desktop

            removeBorderStrategy: PlasmaCore.AppletPopup.AtScreenEdges


            hideOnWindowDeactivate: !Plasmoid.configuration.pin
            visible: systemTrayState.expanded
            appletInterface: root

            backgroundHints: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) ? PlasmaCore.AppletPopup.SolidBackground : PlasmaCore.AppletPopup.StandardBackground

            onVisibleChanged: {
                if (!visible) {
                    if (expandedRepresentation) expandedRepresentation.resetQuickSettings();
                    expandedSync.restart();
                } else {
                    expandedSync.stop();
                    dialog.requestActivate();
                    expandedRepresentation.focusCurrentPage();
                }
            }
            mainItem: ExpandedRepresentation {
                id: expandedRepresentation

                Keys.onEscapePressed: event => {
                    systemTrayState.expanded = false
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
