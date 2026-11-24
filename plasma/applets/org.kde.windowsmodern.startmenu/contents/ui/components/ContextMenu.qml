// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme
import "../code/footerNavigation.js" as FooterNavigation

Item {
    id: contextMenu
    signal actionTriggered(string actionId, var argument, var context)
    signal closed
    property var context: ({})
    property var actions: []
    property Item previousFocus: null
    readonly property bool opened: popup.visible
    readonly property rect popupGeometry: Qt.rect(popup.x, popup.y, popup.width, popup.height)

    FontMetrics {
        id: metrics
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Theme.menuFontSize
    }

    readonly property int popupWidth: Theme.actionMenuWidth(
        actions.reduce((largest, action) => action.type === "separator" ? largest
            : Math.max(largest, metrics.advanceWidth(action.text || "")
                + 2 * Theme.menuTextInset + Theme.menuGlyphSize + Theme.menuIconGap), 0),
        width)

    function moveFocus(direction) {
        const available = actions.map((action, index) => action.type !== "separator"
            && action.enabled !== false && entries.itemAt(index)?.item?.optionEnabled === true);
        const current = actions.findIndex((action, index) => entries.itemAt(index)?.item?.activeFocus === true);
        const next = FooterNavigation.nextEnabledIndex(available, current, direction);
        if (next >= 0)
            entries.itemAt(next).item.forceActiveFocus(Qt.TabFocusReason);
    }

    MouseArea {
        anchors.fill: parent
        visible: popup.visible
        z: 90
        onClicked: contextMenu.close()
    }

    StartMenuSurface {
        id: popup
        objectName: "wmStartContextMenuSurface"
        visible: false
        z: 100
        width: contextMenu.popupWidth
        height: menuColumn.implicitHeight + 2 * Theme.menuOuterInset

        Column {
            id: menuColumn
            width: Math.max(1, popup.width - 2 * Theme.menuOuterInset)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.menuOuterInset
            spacing: 0
            Repeater {
                id: entries
                model: contextMenu.actions
                delegate: Loader {
                    id: entry
                    required property var modelData
                    width: menuColumn.width
                    height: modelData.type === "separator" ? 1 : Theme.menuRowHeight
                    sourceComponent: modelData.type === "separator" ? divider : commandRow

                    Component {
                        id: divider
                        Rectangle {
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                Kirigami.Theme.textColor.b, Theme.separatorOpacity)
                        }
                    }
                    Component {
                        id: commandRow
                        PowerOption {
                            iconSource: entry.modelData.icon || ""
                            label: entry.modelData.text || ""
                            monochrome: iconSource.endsWith("-symbolic")
                            optionEnabled: entry.modelData.enabled !== false
                            onNavigationRequested: direction => contextMenu.moveFocus(direction)
                            onActivated: {
                                const id = entry.modelData.actionId;
                                const argument = entry.modelData.actionArgument ?? null;
                                const savedContext = contextMenu.context;
                                contextMenu.close();
                                contextMenu.actionTriggered(id, argument, savedContext);
                            }
                        }
                    }
                }
            }
        }

        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) contextMenu.close();
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) contextMenu.moveFocus(-1);
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                contextMenu.moveFocus(event.modifiers & Qt.ShiftModifier ? -1 : 1);
        }
    }

    function open(actionList, globalX, globalY, context) {
        if (!actionList || actionList.length === 0) return;
        if (opened) close();
        previousFocus = Window.window ? Window.window.activeFocusItem : null;
        actions = actionList;
        contextMenu.context = context || ({});
        const gap = Theme.menuAnchorGap;
        const h = 2 * Theme.menuOuterInset + actions.reduce((sum, action) =>
            sum + (action.type === "separator" ? 1 : Theme.menuRowHeight), 0);
        popup.x = Math.round(Math.max(gap, Math.min(globalX, width - popupWidth - gap)));
        let py = globalY + gap;
        if (py + h > height - gap) py = globalY - h - gap;
        popup.y = Math.round(Math.max(gap, Math.min(py, height - h - gap)));
        popup.visible = true;
        menuColumn.forceLayout();
        popup.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close() {
        if (!opened) return;
        popup.visible = false;
        actions = [];
        context = ({});
        if (previousFocus && previousFocus.visible) previousFocus.forceActiveFocus(Qt.PopupFocusReason);
        previousFocus = null;
        closed();
    }
}
