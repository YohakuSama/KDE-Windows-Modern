// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../code/startMenuMetrics.js" as Metrics

QQC2.Popup {
    id: menu
    property var modes: []
    property int currentMode: 0
    property int pendingMode: -1
    property Item anchorItem: null
    signal modeChosen(int mode)
    readonly property int rowExtent: Metrics.menuRowExtent(metrics.height)
    FontMetrics { id: metrics; font: Kirigami.Theme.defaultFont }

    // Keep the popup in the Plasma dialog's scene. Native popup windows can
    // lose their transient parent or be positioned in the wrong output space.
    popupType: QQC2.Popup.Item
    modal: true
    dim: false
    focus: true
    padding: Metrics.menuInset
    readonly property real preferredMenuWidth: Math.max(Metrics.viewModeMenuMinimumWidth, ...modes.map(label =>
        metrics.advanceWidth(label) + Metrics.menuGlyphSize + Metrics.viewModeMenuIconGap
            + 2 * Metrics.menuInset + Metrics.viewModeMenuRightReserve))
    width: Math.max(1, Math.min(
        parent ? parent.width - 2 * Metrics.popupEdgeInset : preferredMenuWidth,
        preferredMenuWidth))
    height: Math.max(1, Math.min(
        parent ? parent.height - 2 * Metrics.popupEdgeInset : Metrics.viewModeMenuFallbackHeight,
        modes.length * rowExtent + 2 * Metrics.menuInset))
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    function openAt(button) {
        if (!parent || !button || !button.visible) return;
        if (opened) {
            close();
            return;
        }
        pendingMode = -1;
        anchorItem = button;
        const gap = Metrics.popupAnchorGap;
        const p = button.mapToItem(parent, 0, 0);
        x = Math.max(Metrics.popupEdgeInset,
            Math.min(p.x + button.width - width, parent.width - width - Metrics.popupEdgeInset));
        const below = p.y + button.height + gap;
        const above = p.y - height - gap;
        y = below + height <= parent.height - Metrics.popupEdgeInset
            ? below : Math.max(Metrics.popupEdgeInset, above);
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
    onAnchorItemChanged: if (!anchorItem && visible) close()
    onWidthChanged: if (opened) close()
    onHeightChanged: if (opened) close()
    Connections {
        target: menu.anchorItem
        function onVisibleChanged() { if (!menu.anchorItem?.visible) menu.close(); }
    }

    background: StartMenuBackground {}

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
            height: menu.rowExtent
            text: menu.modes[mode]
            contentItem: RowLayout {
                spacing: Metrics.viewModeMenuIconGap
                Item {
                    Layout.preferredWidth: Metrics.menuGlyphSize
                    Layout.preferredHeight: Metrics.menuGlyphSize
                    Layout.alignment: Qt.AlignVCenter
                    NativeGlyph {
                        anchors.fill: parent
                        roleName: "emblem-ok-symbolic"
                        opacity: menu.currentMode === entry.mode ? 1 : 0
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: entry.text
                    font: metrics.font
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            background: Rectangle {
                radius: Metrics.menuRowRadius
                color: entry.hovered || (entry.ListView.isCurrentItem && list.activeFocus)
                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                    : "transparent"
            }
            onClicked: menu.choose(mode)
        }
    }
}
