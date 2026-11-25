/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Compact vertical-list row delegate for the pinned / all-apps left
 *   column.  Icon + name, hover highlight, keyboard activation.
 *   Right-click uses the shared in-dialog ContextMenu (declared at
 *   rootItem level) via Tools.buildAppActions so the menu is identical
 *   to what search results show.
 *
 *   When dragEnabled is true (PinnedPage), the delegate supports
 *   press-and-drag reordering via view.model.moveRow(from, to).
 ***************************************************************************/

import QtQuick

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/tools.js" as Tools
import "../code/theme.js" as Theme

Item {
    id: item

    readonly property bool inGrid: !!item.GridView.view
    // Grouped rows provide the original source-model context explicitly.
    // Native GridView/ListView delegates retain their existing behavior.
    property var suppliedView: null
    property var appData: typeof model === "undefined" ? ({}) : model
    readonly property var hostView: suppliedView || (inGrid ? item.GridView.view : item.ListView.view)
    readonly property bool currentApp: suppliedView
        ? suppliedView.currentIndex === itemIndex
        : (inGrid ? item.GridView.isCurrentItem : item.ListView.isCurrentItem)
    property bool gridMode: false
    width: hostView ? (inGrid ? hostView.cellWidth
        : (hostView.contentColumnWidth !== undefined ? hostView.contentColumnWidth : hostView.width))
        : (parent ? parent.width : 0)
    height: inGrid && hostView ? hostView.cellHeight
        : (showDescription ? Kirigami.Units.gridUnit * 2 : Math.floor(Kirigami.Units.gridUnit * 1.8))

    clip: !_dragging
    z: _dragging ? 10 : 0

    enabled: !item.appData.disabled

    property int itemIndex: item.appData.index ?? -1
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    property bool showDescription: false
    property bool showInstallBadge: false
    readonly property bool newApplication: showInstallBadge && !!appData.isNewlyInstalled

    // Opt-in drag-to-reorder.  Only the pinned (favorites) list sets this;
    // the all-apps list is alphabetical and not reorderable.
    property bool dragEnabled: false

    Accessible.role: Accessible.MenuItem
    Accessible.name: item.appData.display ?? ""
    Accessible.onPressAction: launchApp()

    // ── Drag state ─────────────────────────────────────────────────────
    // These properties are only mutated when dragEnabled is true.  They
    // track an in-progress drag initiated from pressAndHold or
    // press-then-move beyond a threshold.
    property bool _dragging: false
    property real _dragStartX: 0
    property real _dragOffsetX: 0
    property real _dragStartY: 0
    property real _dragOffsetY: 0

    // ── Hover background ───────────────────────────────────────────────
    Rectangle {
        id: hoverBackground
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.textColor
        opacity: {
            if (item._dragging) return 0;
            if (mouseArea.containsPress) return 0.12;
            if (mouseArea.containsMouse) return 0.07;
            if (item.hostView && item.hostView.activeFocus && item.currentApp) return 0.08;
            return 0;
        }
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    // ── Drop indicator line ────────────────────────────────────────────
    // A thin highlight bar marking the insertion point during a sibling's
    // drag.  Position depends on drag direction:
    //   - dragging UP (target < from): insert BEFORE this delegate → top edge
    //   - dragging DOWN (target > from): insert AFTER this delegate → bottom edge
    //   - target == from: no move, hide.
    Rectangle {
        id: dropIndicator
        visible: {
            var view = item.hostView
            if (!view || item.inGrid || item._dragging) return false
            if (view.dropTargetIndex !== item.itemIndex) return false
            return view.dropTargetIndex !== view.draggingIndex
        }
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        radius: 1
        color: Kirigami.Theme.highlightColor
        // Anchor to the top when dragging up, bottom when dragging down.
        anchors.top: {
            var view = item.hostView
            return (view && view.dropTargetIndex < view.draggingIndex) ? parent.top : undefined
        }
        anchors.bottom: {
            var view = item.hostView
            return (view && view.dropTargetIndex > view.draggingIndex) ? parent.bottom : undefined
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Kirigami.Units.smallSpacing
        color: "transparent"
        border.color: Kirigami.Theme.highlightColor
        border.width: 2
        visible: item.inGrid && item.dragEnabled && item.hostView && !item._dragging
            && item.hostView.dropTargetIndex === item.itemIndex
            && item.hostView.draggingIndex !== item.itemIndex
    }

    // ── Content row ────────────────────────────────────────────────────
    Item {
        id: contentWrapper
        anchors.fill: parent

        // Lift the content during a drag: follow the cursor vertically,
        // scale up slightly, and raise opacity for a "grabbed" feel.
        transform: [
            Translate {
                x: item._dragging ? item._dragOffsetX : 0
                y: item._dragging ? item._dragOffsetY : 0
            },
            Scale {
                xScale: item._dragging ? 1.02 : 1.0
                yScale: item._dragging ? 1.02 : 1.0
                origin.x: contentWrapper.width / 2
                origin.y: contentWrapper.height / 2
            }
        ]
        opacity: item._dragging ? Theme.draggingOpacity : Theme.opacityFull

        Behavior on opacity { NumberAnimation { duration: 90 } }

        Kirigami.Icon {
            id: icon
            x: item.gridMode ? (parent.width - width) / 2 : Kirigami.Units.largeSpacing
            y: item.gridMode ? 9 : (parent.height - height) / 2
            width: item.iconSize
            height: width
            animated: false
            roundToIconSize: false
            source: item.appData.decoration ?? ""
        }

        Column {
            id: textBlock
            x: item.gridMode ? Kirigami.Units.smallSpacing : icon.x + icon.width + Kirigami.Units.largeSpacing
            y: item.gridMode ? icon.y + icon.height + 6 : (parent.height - height) / 2
            width: Math.max(0, parent.width - x - Kirigami.Units.smallSpacing)
            spacing: Kirigami.Units.smallSpacing / 2

            PlasmaComponents3.Label {
                width: parent.width
                horizontalAlignment: item.gridMode ? Text.AlignHCenter : Text.AlignLeft
                maximumLineCount: item.gridMode && !item.newApplication ? 2 : 1
                wrapMode: item.gridMode && !item.newApplication ? Text.Wrap : Text.NoWrap
                elide: Text.ElideRight
                color: Kirigami.Theme.textColor
                font.pixelSize: item.gridMode ? Math.max(12, Kirigami.Theme.smallFont.pixelSize) : Math.max(12, Kirigami.Theme.defaultFont.pixelSize)
                text: item.appData.name || item.appData.display || ""
                textFormat: Text.PlainText
            }

            PlasmaComponents3.Label {
                objectName: "wmNewAppBadge"
                visible: item.newApplication
                width: parent.width
                horizontalAlignment: item.gridMode ? Text.AlignHCenter : Text.AlignLeft
                maximumLineCount: 1
                color: Kirigami.Theme.highlightColor
                font.pixelSize: Math.max(11, Kirigami.Theme.smallFont.pixelSize)
                text: i18n("New")
                textFormat: Text.PlainText
            }

            PlasmaComponents3.Label {
                visible: item.showDescription && !item.newApplication && text.length > 0
                width: parent.width
                maximumLineCount: 1
                elide: Text.ElideRight
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                text: item.appData.description ?? ""
                textFormat: Text.PlainText
            }
        }
    }

    // ── Mouse handling ─────────────────────────────────────────────────
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: item.dragEnabled && (pressedButtons & Qt.LeftButton) !== 0
        cursorShape: item._dragging ? Qt.DragMoveCursor : Qt.PointingHandCursor
        // Keep drag above sibling delegates so the lifted content paints
        // on top while being dragged.
        z: item._dragging ? 20 : 10

        // Drag threshold — distance the cursor must travel from the press
        // point before we treat it as a drag rather than a click.
        readonly property real dragThreshold: Kirigami.Units.gridUnit * 0.4

        property real _pressX: -1
        property real _pressY: -1
        property bool _mightDrag: false

        onPressed: mouse => {
            _pressX = mouse.x;
            _pressY = mouse.y;
            _mightDrag = item.dragEnabled && mouse.button === Qt.LeftButton;
        }

        onPositionChanged: mouse => {
            if (!_mightDrag || item._dragging) {
                if (item._dragging) updateDrag(mouse.x, mouse.y);
                return;
            }

            // Start a drag once the cursor moves past the threshold.
            if (_mightDrag) {
                var dx = mouse.x - _pressX;
                var dy = mouse.y - _pressY;
                if (Math.abs(dy) > mouseArea.dragThreshold || Math.abs(dx) > mouseArea.dragThreshold) {
                    beginDrag(mouse.x, mouse.y);
                }
            }
        }

        onReleased: mouse => {
            if (item._dragging) {
                updateDrag(mouse.x, mouse.y);
                endDrag();
                _mightDrag = false;
                _pressX = -1;
                _pressY = -1;
                return;
            }
            _mightDrag = false;
            _pressX = -1;
            _pressY = -1;

            // Releasing outside the tile is a cancel, not an application launch.
            if (mouse.x < 0 || mouse.y < 0 || mouse.x >= width || mouse.y >= height) return;
            var view = item.hostView;
            if (view) view.forceActiveFocus();
            if (mouse.button === Qt.RightButton) {
                openContextMenu(mouse.x, mouse.y);
                return;
            }
            launchApp();
        }

        onCanceled: {
            item._dragging = false;
            item._dragOffsetX = 0;
            item._dragOffsetY = 0;
            _mightDrag = false;
            if (item.dragEnabled && item.hostView) {
                item.hostView.draggingIndex = -1;
                item.hostView.dropTargetIndex = -1;
            }
        }

        onClicked: {
            // Suppress the implicit clicked on drag release — handled in onReleased.
            if (item._dragging) {
                // already ended in onReleased
            }
        }

        // ── Drag helpers ──────────────────────────────────────────────
        function beginDrag(localX, localY) {
            var view = item.hostView;
            if (!view || !view.model || typeof view.model.moveRow !== "function") return;

            item._dragging = true;
            item._dragStartX = localX;
            item._dragOffsetX = 0;
            item._dragStartY = localY;
            item._dragOffsetY = 0;
            view.draggingIndex = item.itemIndex;
            view.dropTargetIndex = item.itemIndex;
        }

        function updateDrag(localX, localY) {
            var view = item.hostView;
            if (!view) return;

            // Offset relative to the press point, mapped into view coords.
            var delta = localY - item._dragStartY;
            item._dragOffsetY = delta;
            if (item.inGrid) {
                item._dragOffsetX = localX - item._dragStartX;
                const visiblePoint = item.mapToItem(view, localX, localY);
                const inside = visiblePoint.x >= 0 && visiblePoint.x < view.width
                    && visiblePoint.y >= 0 && visiblePoint.y < view.height;
                const point = item.mapToItem(view.contentItem, localX, localY);
                view.dropTargetIndex = inside ? view.indexAt(point.x, point.y) : -1;
                return;
            }

            // Compute the drop target by counting how many siblings have
            // their centre ABOVE the dragged item's current centre.  That
            // count is the target index — it only changes when the dragged
            // item actually crosses a sibling's midpoint, so:
            //   - first item dragged up → 0 above → target 0 → no-op
            //   - last item dragged down → all above → target N-1 → no-op
            //   - slight drag without crossing a centre → no-op
            var myCenter = item.mapToItem(view, 0, item.height / 2).y + delta;
            var target = 0;
            for (var i = 0; i < view.count; i++) {
                if (i === item.itemIndex) continue;
                var other = view.itemAtIndex(i);
                if (!other) continue;
                var otherCenter = other.mapToItem(view, 0, other.height / 2).y;
                if (otherCenter < myCenter) {
                    target++;
                }
            }

            view.dropTargetIndex = target;
        }

        function endDrag() {
            var view = item.hostView;
            var from = item.itemIndex;
            var to = view ? view.dropTargetIndex : -1;

            item._dragging = false;
            item._dragOffsetX = 0;
            item._dragOffsetY = 0;

            if (view) {
                view.draggingIndex = -1;
                view.dropTargetIndex = -1;
            }

            // Perform the move.  moveRow(from, to) moves the row at
            // 'from' to position 'to' in the favorites model.  The model
            // emits the appropriate moveRows signals so the ListView
            // repositions delegates without a full reset.
            if (view && view.model && typeof view.model.moveRow === "function"
                    && to >= 0 && to !== from) {
                view.model.moveRow(from, to);
            }
        }
    }

    PlasmaComponents3.ToolTip {
        visible: mouseArea.containsMouse && !mouseArea.containsPress && !item._dragging
        text: item.appData.name || item.appData.display || ""
        delay: Kirigami.Units.toolTipDelay
    }

    function launchApp() {
        var view = item.hostView
        if (view && typeof view.activateRow === "function") {
            view.activateRow(item.itemIndex);
            return;
        }
        if (view && view.model && typeof view.model.trigger === "function") {
            if (view.model.trigger(item.itemIndex, "", null))
                root.closeMenu();
        }
    }

    function openContextMenu(localX, localY) {
        // A category is a navigation row, not a pinnable application.
        if (item.appData.isParent) return;
        var favModel = (typeof kicker !== "undefined" && kicker.globalFavorites)
                       ? kicker.globalFavorites : null
        var favId = item.appData.favoriteId ?? ""
        var url = item.appData.url ?? ""
        var actionList = item.appData.actionList ?? null
        var acts = Tools.buildAppActions(i18n, favModel, favId, url, actionList)
        if (acts.length === 0) return

        var pos = item.mapToItem(sharedContextMenu, localX, localY)
        var view = item.hostView
        sharedContextMenu.open(acts, pos.x, pos.y, {
            model: view ? view.model : null,
            index: item.itemIndex
        })
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            event.accepted = true;
            launchApp();
        }
    }
}
