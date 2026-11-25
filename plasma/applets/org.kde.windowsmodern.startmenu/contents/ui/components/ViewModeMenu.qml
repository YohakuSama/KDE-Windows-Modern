// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Popup {
    id: menu
    property var modes: []
    property int currentMode: 0
    property int pendingMode: -1
    property Item anchorItem: null
    signal modeChosen(int mode)

    // Keep the popup in the Plasma dialog's scene. Native popup windows can
    // lose their transient parent or be positioned in the wrong output space.
    popupType: QQC2.Popup.Item
    modal: true
    dim: false
    focus: true
    padding: 4
    width: Math.min(parent ? parent.width - 16 : 160, 160)
    height: Math.min(parent ? parent.height - 16 : 120, modes.length * 36 + 8)
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    function openAt(button) {
        if (!parent || !button || !button.visible) return;
        if (opened) {
            close();
            return;
        }
        pendingMode = -1;
        anchorItem = button;
        const gap = 4;
        const p = button.mapToItem(parent, 0, 0);
        x = Math.max(8, Math.min(p.x + button.width - width, parent.width - width - 8));
        const below = p.y + button.height + gap;
        const above = p.y - height - gap;
        y = below + height <= parent.height - 8 ? below : Math.max(8, above);
        open();
    }
    function choose(mode) {
        pendingMode = mode;
        close();
    }
    onOpened: if (list.count > 0) {
        list.currentIndex = Math.max(0, list.count - 1 - currentMode);
        list.forceActiveFocus();
    }
    onClosed: {
        const mode = pendingMode;
        pendingMode = -1;
        anchorItem = null;
        // A mode change can destroy the originating header. Dispatch only
        // after the stable popup has fully closed.
        if (mode >= 0) modeChosen(mode);
    }
    onCurrentModeChanged: if (opened && pendingMode < 0) close()

    background: Rectangle {
        radius: 8
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
    }

    contentItem: ListView {
        id: list
        clip: true
        model: menu.modes.length
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        Keys.onReturnPressed: if (currentIndex >= 0) menu.choose(count - 1 - currentIndex)
        Keys.onEnterPressed: if (currentIndex >= 0) menu.choose(count - 1 - currentIndex)
        delegate: QQC2.ItemDelegate {
            id: entry
            required property int index
            readonly property int mode: menu.modes.length - 1 - index
            objectName: "wmViewMode_" + mode
            width: ListView.view.width
            height: 36
            text: menu.modes[mode]
            contentItem: RowLayout {
                spacing: 8
                Kirigami.Icon {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    source: "emblem-ok-symbolic"
                    opacity: menu.currentMode === entry.mode ? 1 : 0
                    isMask: true
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: entry.text
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            background: Rectangle {
                radius: 4
                color: entry.hovered || (entry.ListView.isCurrentItem && list.activeFocus)
                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                    : "transparent"
            }
            onClicked: menu.choose(mode)
        }
    }
}
