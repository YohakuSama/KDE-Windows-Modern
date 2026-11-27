// SPDX-License-Identifier: GPL-3.0-or-later
// One scene-local popup for all Start context menus.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme

Item {
    id: contextMenu
    signal actionTriggered(string actionId, var argument, var context)
    signal closed
    readonly property bool opened: popup.visible
    property var context: ({})
    property var actions: []
    property var pendingAction: null
    readonly property int rowHeight: Theme.menuRowExtent(metrics.height)
    readonly property int separatorHeight: 9
    readonly property int gap: 8

    FontMetrics { id: metrics; font: Kirigami.Theme.defaultFont }

    // Every source model can change while a menu is open (not just All
    // Apps). Discard captured row indexes before an action can use them.
    component ModelGuard: Connections {
        ignoreUnknownSignals: true
        function onModelReset() { contextMenu.close(); }
        function onRowsInserted() { contextMenu.close(); }
        function onRowsRemoved() { contextMenu.close(); }
        function onRowsMoved() { contextMenu.close(); }
        function onLayoutChanged() { contextMenu.close(); }
        function onDataChanged() { contextMenu.close(); }
    }
    ModelGuard {
        target: contextMenu.opened && typeof contextMenu.context.model === "object"
            ? contextMenu.context.model : null
    }
    ModelGuard {
        target: contextMenu.opened && contextMenu.context.resolvedModel !== contextMenu.context.model
            && typeof contextMenu.context.resolvedModel === "object" ? contextMenu.context.resolvedModel : null
    }

    function selectable(index) {
        const action = actions[index];
        return !!action && action.type !== "separator"
            && action.enabled !== false && typeof action.actionId === "string";
    }

    function step(direction) {
        let index = list.currentIndex;
        if (index < 0 && direction < 0) index = 0;
        for (let n = 0; n < actions.length; ++n) {
            index = (index + direction + actions.length) % actions.length;
            if (selectable(index)) {
                list.currentIndex = index;
                list.positionViewAtIndex(index, ListView.Contain);
                return;
            }
        }
    }

    function activate(index) {
        if (!selectable(index) || pendingAction) return;
        pendingAction = { action: actions[index], context: context };
        popup.close();
    }

    function open(actionList, localX, localY, details) {
        if (!actionList || !actionList.length || opened || width <= 2 * gap || height <= 2 * gap)
            return;
        actions = actionList;
        context = details || ({});
        pendingAction = null;
        let widest = 0;
        let wantedHeight = 2 * Theme.menuInset;
        for (const action of actions) {
            wantedHeight += action.type === "separator" ? separatorHeight : rowHeight;
            widest = Math.max(widest, metrics.advanceWidth(action.text || "") + (action.shortcut ? metrics.advanceWidth(action.shortcut) + 24 : 0));
        }
        popup.width = Math.min(width - 2 * gap, Math.max(184, Math.min(400, widest + 72)));
        popup.height = Math.min(height - 2 * gap, wantedHeight);
        popup.x = Math.max(gap, Math.min(localX, width - popup.width - gap));
        const below = localY + 4;
        const above = localY - popup.height - 4;
        popup.y = Math.max(gap, Math.min(below + popup.height <= height - gap ? below : above,
                                        height - popup.height - gap));
        popup.open();
    }

    function close() {
        pendingAction = null;
        if (popup.visible) popup.close();
    }
    onWidthChanged: if (opened) close()
    onHeightChanged: if (opened) close()

    QQC2.Popup {
        id: popup
        objectName: "wmStartContextPopup"
        parent: contextMenu
        popupType: QQC2.Popup.Item
        modal: true
        dim: false
        focus: true
        padding: Theme.menuInset
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onOpened: {
            list.forceActiveFocus();
            list.currentIndex = -1;
        }
        onClosed: {
            const pending = contextMenu.pendingAction;
            contextMenu.pendingAction = null;
            contextMenu.actions = [];
            contextMenu.context = ({});
            contextMenu.closed();
            if (pending)
                contextMenu.actionTriggered(pending.action.actionId,
                    pending.action.actionArgument ?? null, pending.context);
        }
        background: StartMenuBackground {}
        contentItem: ListView {
            id: list
            model: contextMenu.actions
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            HoverHandler { id: menuHover }
            QQC2.ScrollBar.vertical: StartScrollBar {
                viewportHovered: menuHover.hovered
                scrolling: list.moving
            }
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Up: contextMenu.step(-1); break;
                case Qt.Key_Down: contextMenu.step(1); break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space: contextMenu.activate(currentIndex); break;
                case Qt.Key_Escape: contextMenu.close(); break;
                default: break;
                }
                event.accepted = true;
            }
            delegate: QQC2.ItemDelegate {
                id: row
                required property int index
                required property var modelData
                readonly property bool separator: modelData.type === "separator"
                width: list.width
                height: separator ? contextMenu.separatorHeight : contextMenu.rowHeight
                leftPadding: Theme.menuTextInset
                rightPadding: Theme.menuTextInset
                enabled: contextMenu.selectable(index)
                focusPolicy: Qt.NoFocus
                text: modelData.text || ""
                background: Rectangle {
                    radius: Theme.menuRowRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, row.separator ? 0
                            : row.down ? 0.12 : row.hovered || (row.ListView.isCurrentItem && list.activeFocus) ? 0.08 : 0)
                }
                Rectangle {
                    visible: row.separator
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                }
                contentItem: RowLayout {
                    visible: !row.separator
                    spacing: Theme.menuIconGap
                    Item {
                        Layout.preferredWidth: Theme.menuGlyphSize
                        Layout.preferredHeight: Theme.menuGlyphSize
                        Layout.alignment: Qt.AlignVCenter
                        NativeGlyph {
                            objectName: "wmStartActionGlyph"
                            anchors.fill: parent
                            // App/runner action names are not application identity icons.
                            // Keep unknown actions text-only rather than using the theme.
                            roleName: typeof row.modelData.icon === "string" ? row.modelData.icon : ""
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.text
                        font: metrics.font
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        visible: !!row.modelData.shortcut
                        text: row.modelData.shortcut || ""
                        elide: Text.ElideRight
                        opacity: 0.65
                        font: metrics.font
                        textFormat: Text.PlainText
                    }
                }
                onClicked: contextMenu.activate(index)
            }
        }
    }
}
