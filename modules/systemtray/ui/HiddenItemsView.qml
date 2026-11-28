/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import "lib" as Lib
import "js/colorType.js" as ColorType

PlasmaComponents3.ScrollView {
    id: hiddenTasksView

    property alias layout: hiddenTasks

    required property Item trayRoot
    required property SystemTrayState trayState
    required property var overflowModel
    property Item preloadHost: null
    property Item popupContentItem: null

    // One geometry plan from ExpandedRepresentation, including work-area
    // limits and the optional scroll rail. Do not recompute from the
    // ScrollView's effective width after its scrollbar becomes visible.
    required property var metrics
    readonly property int maximumRows: metrics.maximumRows
    readonly property int rows: metrics.rows
    readonly property bool scrolls: metrics.scrolls
    readonly property int contentRowsHeight: metrics.contentHeight

    hoverEnabled: true
    padding: 0
    background: null
    HoverHandler { id: viewportHover }
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
    QQC2.ScrollBar.vertical: Lib.FluentScrollBar {
        width: hiddenTasksView.metrics.railWidth
        policy: hiddenTasksView.scrolls ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff
        dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
        viewportHovered: viewportHover.hovered
        scrolling: hiddenTasks.moving || hiddenTasks.flicking
    }

    GridView {
        id: hiddenTasks

        readonly property int columns: 5

        // Compact Windows 11 overflow grid, independent of Quick Settings.

        cellWidth: hiddenTasksView.metrics.cellWidth
        cellHeight: hiddenTasksView.metrics.cellHeight
        boundsBehavior: Flickable.StopAtBounds

        currentIndex: -1
        // Individual AbstractItem delegates draw their own 4px Windows 11 hover/focus tile.
        highlight: null
        highlightMoveDuration: 0

        pixelAligned: true

        readonly property int itemCount: model.count

        model: hiddenTasksView.overflowModel
        delegate: ItemLoader {
            trayRoot: hiddenTasksView.trayRoot
            trayState: hiddenTasksView.trayState
            preloadHost: hiddenTasksView.preloadHost
            popupContentItem: hiddenTasksView.popupContentItem
            overflowGridView: hiddenTasks
            // Use full cells so the icon and hover target share the same center.
            width: hiddenTasks.cellWidth
            height: hiddenTasks.cellHeight
            Accessible.role: Accessible.ListItem
        }

        keyNavigationEnabled: true
        activeFocusOnTab: true

        KeyNavigation.up: hiddenTasksView.KeyNavigation.up

        onActiveFocusChanged: {
            if (activeFocus && currentIndex === -1) {
                currentIndex = 0
            } else if (!activeFocus && currentIndex >= 0) {
                currentIndex = -1
            }
        }
    }
}
