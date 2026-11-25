// SPDX-License-Identifier: GPL-3.0-or-later
// A presentation of the shared, native Klipper history, not a second clipboard.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.clipboard as Clipboard
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../lib" as Lib

ColumnLayout {
    id: page
    property var history: nativeHistory
    property var historyRows: history
    property Component footer: null
    signal back
    signal dismissed
    spacing: 0

    Clipboard.HistoryModel { id: nativeHistory }

    function selectEntry(uuid) {
        if (!uuid || !history) return;
        // Klipper moves the actual MIME item to the top and updates the
        // real system clipboard. Works for text, URLs and images alike.
        history.moveToTop(uuid);
        dismissed();
    }

    function removeEntry(uuid) {
        if (uuid && history) history.remove(uuid);
    }

    Lib.PageHeader {
        title: i18n("Clipboard")
        showSwitch: false
        onBack: page.back()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 10
        spacing: 8

        PlasmaComponents3.Label {
            text: i18n("Clipboard history")
            font.pixelSize: 14
            Layout.fillWidth: true
        }
        PlasmaComponents3.ToolButton {
            objectName: "wmClipboardPinnedFilter"
            visible: page.history && page.history.starredCount > 0
            text: i18n("Pinned items")
            checkable: true
            checked: page.history && page.history.starredOnly
            display: PlasmaComponents3.AbstractButton.IconOnly
            icon.name: checked ? "starred-symbolic" : "non-starred-symbolic"
            icon.width: 16
            icon.height: 16
            onClicked: if (page.history) page.history.starredOnly = checked
            PlasmaComponents3.ToolTip { text: parent.text }
        }
        PlasmaComponents3.Button {
            objectName: "wmClipboardClearAll"
            visible: page.history && page.history.sourceCount > 0
            text: i18n("Clear all")
            onClicked: if (page.history) page.history.clearHistory()
        }
        PlasmaComponents3.ToolButton {
            text: i18n("Close")
            display: PlasmaComponents3.AbstractButton.IconOnly
            icon.name: "window-close-symbolic"
            icon.width: 16
            icon.height: 16
            onClicked: page.dismissed()
            PlasmaComponents3.ToolTip { text: parent.text }
        }
    }

    ListView {
        id: historyList
        objectName: "wmClipboardHistory"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 16
        Layout.rightMargin: 8
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        visible: count > 0
        model: page.historyRows
        currentIndex: -1
        PlasmaComponents3.ScrollBar.vertical: Lib.FluentScrollBar {
            scrolling: historyList.moving
        }

        delegate: Item {
            id: entry
            required property var model
            required property int index
            objectName: "wmClipboardCard_" + index
            readonly property string uuid: String(model.uuid || "")
            readonly property string displayText: String(model.display || "")
            readonly property url previewUrl: model.decoration || ""
            readonly property bool hasImage: String(previewUrl).length > 0
            readonly property bool pinned: !!model.starred
            width: Math.max(1, historyList.width - 12)
            height: hasImage ? 96 : 76
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: hasImage ? i18n("Image") + " " + displayText : displayText
            Accessible.onPressAction: page.selectEntry(uuid)
            Keys.onReturnPressed: page.selectEntry(uuid)
            Keys.onEnterPressed: page.selectEntry(uuid)
            Keys.onSpacePressed: page.selectEntry(uuid)
            Keys.onDeletePressed: page.removeEntry(uuid)

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, entryMouse.containsPress ? 0.10
                    : entryMouse.containsMouse || entry.activeFocus ? 0.075 : 0.045)
                border.width: 1
                border.color: entry.activeFocus ? Kirigami.Theme.textColor
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, 0.12)
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: entry.uuid.length > 0
                onClicked: page.selectEntry(entry.uuid)
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Image {
                        objectName: "wmClipboardImage"
                        anchors.fill: parent
                        visible: entry.hasImage
                        source: entry.previewUrl
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignLeft
                        verticalAlignment: Image.AlignVCenter
                        asynchronous: true
                        cache: false
                        sourceSize.width: 360
                        sourceSize.height: 180
                    }

                    PlasmaComponents3.Label {
                        objectName: "wmClipboardText"
                        anchors.fill: parent
                        visible: !entry.hasImage
                        text: entry.displayText
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    PlasmaComponents3.ToolButton {
                        objectName: "wmClipboardRemove"
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 28
                        text: i18n("Remove")
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        icon.name: "edit-delete-symbolic"
                        icon.width: 14
                        icon.height: 14
                        onClicked: page.removeEntry(entry.uuid)
                        PlasmaComponents3.ToolTip { text: parent.text }
                    }

                    PlasmaComponents3.ToolButton {
                        objectName: "wmClipboardPin"
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 28
                        text: entry.pinned ? i18n("Unpin") : i18n("Pin")
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        icon.name: entry.pinned ? "starred-symbolic" : "window-pin"
                        icon.width: 14
                        icon.height: 14
                        // The real writable Klipper starred role persists
                        // the pinned state. Never maintain a parallel list.
                        onClicked: entry.model.starred = !entry.pinned
                        PlasmaComponents3.ToolTip { text: parent.text }
                    }
                }
            }
        }
    }

    PlasmaComponents3.Label {
        objectName: "wmClipboardEmpty"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: historyList.count === 0
        text: i18n("Clipboard is empty")
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
