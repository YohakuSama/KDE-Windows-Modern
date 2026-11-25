/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Shared in-dialog context menu popup for list delegates.  A single
 *   instance lives at the rootItem level; delegates call open() with
 *   their action list and position.  Avoids stacking multiple popups.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme

Item {
    id: contextMenu

    Win11Palette { id: fluent }

    signal actionTriggered(string actionId, var argument, var context)
    signal closed

    readonly property int rowHeight: Math.max(fluent.controlHeight, Math.ceil(menuMetrics.height) + 12)

    // Caller-supplied context (e.g. { model, index }) forwarded back with
    // actionTriggered so the shell can dispatch to the right model.
    property var context: ({})

    // ── Click catcher ──────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: popup.visible
        z: 90
        onClicked: contextMenu.close()
    }

    // ── The floating panel ─────────────────────────────────────────────
    Rectangle {
        id: popup
        visible: false
        z: 100
        width: Kirigami.Units.gridUnit * 15
        height: menuColumn.implicitHeight + 2 * fluent.menuPadding
        radius: fluent.menuRadius
        color: fluent.menuBackground
        border.width: 1
        border.color: fluent.menuBorder

        Column {
            id: menuColumn
            width: popup.width - 2 * fluent.menuPadding
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: fluent.menuPadding
            spacing: 0

            Repeater {
                model: contextMenu.actions

                delegate: Item {
                    width: menuColumn.width
                    height: modelData.type === "separator" ? 1 : contextMenu.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: modelData.type !== "separator"
                        radius: fluent.controlRadius
                        color: rowHover.containsPress ? fluent.controlPressed
                            : rowHover.containsMouse ? fluent.controlHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: modelData.type === "separator"
                        color: Qt.rgba(Kirigami.Theme.textColor.r,
                                       Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, Theme.separatorOpacity)
                    }

                    RowLayout {
                        visible: modelData.type !== "separator"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: fluent.rowPadding
                        anchors.rightMargin: fluent.rowPadding
                        spacing: fluent.rowPadding

                        Kirigami.Icon {
                            Layout.preferredWidth: fluent.menuIconSize
                            Layout.preferredHeight: fluent.menuIconSize
                            source: modelData.icon || ""
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: modelData.text || ""
                            color: Kirigami.Theme.textColor
                            font: Kirigami.Theme.defaultFont
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        visible: modelData.type !== "separator"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            // File-level ids are not accessible inside
                            // Repeater delegates in Qt 6, so walk the
                            // parent chain: MouseArea -> delegate Item ->
                            // Column -> popup Rectangle -> contextMenu Item
                            var menu = parent.parent.parent.parent
                            menu.actionTriggered(modelData.actionId, modelData.actionArgument || null, menu.context)
                            menu.close()
                        }
                    }
                }
            }
        }
    }

    property var actions: []

    // Measure rendered widths, not character counts (CJK and Latin differ).
    FontMetrics {
        id: menuMetrics
        font: Kirigami.Theme.defaultFont
    }

    readonly property real widestTextWidth: {
        let result = 0;
        for (const action of contextMenu.actions) {
            if (action.type !== "separator")
                result = Math.max(result, menuMetrics.advanceWidth(action.text || ""));
        }
        return result;
    }

    readonly property int popupWidth: Math.max(1, Math.min(
        Math.ceil(Math.max(160, widestTextWidth + fluent.menuIconSize + 3 * fluent.rowPadding + 2 * fluent.menuPadding)),
        contextMenu.width - 2 * fluent.rowPadding
    ))

    function open(actionList, globalX, globalY, context) {
        contextMenu.actions = actionList
        contextMenu.context = context || ({})
        if (actionList.length === 0) return

        var popupW = contextMenu.popupWidth
        var gap = fluent.rowPadding

        // Compute the expected height from the action list itself rather
        // than measuring popup.height after make-visible — the latter is
        // stale on the first open because QML layout hasn't run yet.
        var itemH = contextMenu.rowHeight
        var popupH = 2 * fluent.menuPadding
        for (var i = 0; i < actionList.length; i++) {
            popupH += (actionList[i].type === "separator") ? 1 : itemH
        }

        var px = Math.max(gap, Math.min(globalX, contextMenu.width - popupW - gap))
        var py = globalY + gap
        if (py + popupH > contextMenu.height - gap) {
            py = globalY - popupH - gap
            if (py < gap) py = gap
        }

        popup.x = px
        popup.y = py
        popup.width = popupW
        popup.visible = true
    }

    function close() {
        popup.visible = false
        contextMenu.actions = []
        contextMenu.context = ({})
        contextMenu.closed()
    }
}
