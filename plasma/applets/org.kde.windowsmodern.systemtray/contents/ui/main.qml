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

ContainmentItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool reverseLayout: Plasmoid.configuration.reverseIconOrder
    property Item hoveredQuickSetting: null

    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : mainLayout.implicitWidth + Kirigami.Units.smallSpacing
    Layout.minimumHeight: vertical ? mainLayout.implicitHeight + Kirigami.Units.smallSpacing : Kirigami.Units.iconSizes.small

    LayoutMirroring.enabled: !vertical && ((Application.layoutDirection === Qt.RightToLeft) !== reverseLayout)
    LayoutMirroring.childrenInherit: true

    readonly property alias systemTrayState: systemTrayState
    readonly property alias itemSize: tasksGrid.itemSize
    readonly property alias visibleLayout: tasksGrid
    readonly property alias hiddenLayout: expandedRepresentation.hiddenLayout
    readonly property bool oneRowOrColumn: tasksGrid.rowsOrColumns === 1

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

            GridView {
                id: tasksGrid

                // Windows 11: overflow first, then visible icons and the
                // network/volume/battery group (ordered by WindowsTray::tail).
                Layout.row: root.vertical && !root.reverseLayout ? 1 : 0
                Layout.column: root.vertical ? 0 : 1

                Layout.alignment: Qt.AlignCenter

                interactive: false //disable features we don't need
                flow: root.vertical ? GridView.LeftToRight : GridView.TopToBottom

                // Tell the grid to populate bottom-to-top when flipped on a vertical panel
                verticalLayoutDirection: (root.vertical && root.reverseLayout) ? GridView.BottomToTop : GridView.TopToBottom

                // The icon size to display when not using the auto-scaling setting
                readonly property int smallIconSize: Kirigami.Units.iconSizes.small

                readonly property bool autoSize: Plasmoid.configuration.scaleIconsToFit

                readonly property int gridThickness: root.vertical ? root.width : root.height
                // Should change to 2 rows/columns on a 56px panel (in standard DPI)
                readonly property int rowsOrColumns: autoSize ? 1 : Math.max(1, Math.min(count, Math.floor(gridThickness / (smallIconSize + Kirigami.Units.smallSpacing))))

                // Add margins only if the panel is larger than a small icon (to avoid large gaps between tiny icons)
                readonly property int cellSpacing: Kirigami.Units.smallSpacing * Plasmoid.configuration.iconSpacing
                readonly property int smallSizeCellLength: gridThickness < smallIconSize ? smallIconSize : smallIconSize + cellSpacing

                cellHeight: {
                    if (root.vertical) {
                        return autoSize ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength
                    } else {
                        return autoSize ? root.height : Math.floor(root.height / rowsOrColumns)
                    }
                }
                cellWidth: {
                    if (root.vertical) {
                        return autoSize ? root.width : Math.floor(root.width / rowsOrColumns)
                    } else {
                        return autoSize ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength
                    }
                }

                //depending on the form factor, we are calculating only one dimension, second is always the same as root/parent
                implicitHeight: root.vertical ? cellHeight * Math.ceil(count / rowsOrColumns) : root.height
                implicitWidth: !root.vertical ? cellWidth * Math.ceil(count / rowsOrColumns) : root.width

                readonly property int itemSize: {
                    if (autoSize) {
                        return Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(root.width, root.height) / rowsOrColumns, Kirigami.Units.iconSizes.enormous))
                    } else {
                        return smallIconSize
                    }
                }

                model: activeModel

                delegate: ItemLoader {
                    id: delegate

                    width: tasksGrid.cellWidth
                    height: tasksGrid.cellHeight

                    // We need to recalculate the stacking order of the z values due to how keyboard navigation works
                    // the tab order depends exclusively from this, so we redo it as the position in the list
                    // ensuring tab navigation focuses the expected items
                    Component.onCompleted: {
                        let item = tasksGrid.itemAtIndex(index - 1);
                        if (item) {
                            Plasmoid.stackItemBefore(delegate, item)
                        } else {
                            item = tasksGrid.itemAtIndex(index + 1);
                        }
                        if (item) {
                            Plasmoid.stackItemAfter(delegate, item)
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
                iconSize: Kirigami.Units.iconSizes.small
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
