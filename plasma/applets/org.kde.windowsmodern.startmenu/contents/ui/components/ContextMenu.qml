// SPDX-License-Identifier: GPL-3.0-or-later
// One scene-local popup for all Start context menus.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: contextMenu
    signal actionTriggered(string actionId, var argument, var context)
    signal closed
    readonly property bool opened: popup.visible
    property var context: ({})
    property var actions: []
    property var pendingAction: null
    readonly property int rowHeight: 32
    readonly property int gap: 8

    FontMetrics { id: metrics; font: Kirigami.Theme.defaultFont }

    function selectable(index) {
        const action = actions[index];
        return !!action && action.type !== "separator"
            && action.enabled !== false && typeof action.actionId === "string";
    }

    function step(direction) {
        let index = list.currentIndex;
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
        let wantedHeight = 8;
        for (const action of actions) {
            wantedHeight += action.type === "separator" ? 1 : rowHeight;
            widest = Math.max(widest, metrics.advanceWidth(action.text || ""));
        }
        popup.width = Math.min(width - 2 * gap, Math.max(160, Math.min(360, widest + 64)));
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
        padding: 4
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        onOpened: {
            list.currentIndex = -1;
            contextMenu.step(1);
            list.forceActiveFocus();
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
        background: Rectangle {
            radius: 8
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.10)
        }
        contentItem: ListView {
            id: list
            model: contextMenu.actions
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }
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
                height: separator ? 1 : contextMenu.rowHeight
                enabled: contextMenu.selectable(index)
                focusPolicy: Qt.NoFocus
                text: modelData.text || ""
                background: Rectangle {
                    radius: row.separator ? 0 : 4
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, row.separator ? 0.10
                            : row.hovered || (row.ListView.isCurrentItem && list.activeFocus) ? 0.08 : 0)
                }
                contentItem: RowLayout {
                    visible: !row.separator
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        source: row.modelData.icon || ""
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: row.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
                onClicked: contextMenu.activate(index)
            }
        }
    }
}
