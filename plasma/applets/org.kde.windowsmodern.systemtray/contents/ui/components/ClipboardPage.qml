// SPDX-License-Identifier: GPL-3.0-or-later
// Use the real Klipper history; moveToTop preserves the complete MIME payload.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.clipboard as Clipboard
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../lib" as Lib

ColumnLayout {
    id: page
    spacing: 0
    property Component footer: null
    signal back()
    signal itemSelected()

    Clipboard.HistoryModel { id: historyModel }

    Lib.PageHeader {
        title: i18n("Clipboard")
        showAction: historyModel.count > 0
            && (historyModel.starredCount === undefined || historyModel.count > historyModel.starredCount)
        actionText: i18n("Clear all")
        onActionTriggered: historyModel.clearHistory()
        onBack: page.back()
    }

    ListView {
        id: history
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        model: historyModel
        visible: count > 0
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {}

        delegate: Rectangle {
            id: card
            required property var model
            readonly property bool isImage: model.type === 4
            readonly property bool supportsPin: model.starred !== undefined
            readonly property bool pinned: supportsPin && model.starred
            readonly property color fg: Kirigami.Theme.textColor
            width: Math.max(1, history.width - (history.contentHeight > history.height ? 16 : 0))
            height: isImage ? 108 : 76
            radius: 6
            color: Qt.rgba(fg.r, fg.g, fg.b, selectArea.containsMouse ? 0.10 : 0.055)
            border.width: selectArea.activeFocus ? 2 : 1
            border.color: selectArea.activeFocus ? Kirigami.Theme.highlightColor
                : Qt.rgba(fg.r, fg.g, fg.b, 0.12)

            function selectItem() {
                if (!model.uuid) return;
                historyModel.moveToTop(model.uuid);
                page.itemSelected();
            }

            MouseArea {
                id: selectArea
                anchors.fill: parent
                hoverEnabled: true
                activeFocusOnTab: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: card.isImage ? i18n("Image") : String(card.model.display || "")
                Accessible.onPressAction: card.selectItem()
                Keys.onReturnPressed: card.selectItem()
                Keys.onEnterPressed: card.selectItem()
                Keys.onSpacePressed: card.selectItem()
                onClicked: card.selectItem()
            }

            Image {
                id: preview
                visible: card.isImage
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: Math.max(1, Math.min(card.width - 62, 220))
                source: card.isImage ? card.model.decoration : ""
                sourceSize.height: 200
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                cache: false
            }

            PlasmaComponents3.Label {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: actionsColumn.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                visible: !card.isImage || preview.status === Image.Error
                text: card.isImage ? i18n("Image") : String(card.model.display || "")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 3
            }

            Column {
                id: actionsColumn
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: 32
                spacing: Math.max(0, height - 64)

                PlasmaComponents3.ToolButton {
                    width: 32
                    height: 32
                    text: i18n("More actions")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    icon.name: "view-more-symbolic"
                    icon.width: 16
                    icon.height: 16
                    onClicked: actions.open()
                    QQC2.Menu {
                        id: actions
                        QQC2.MenuItem {
                            text: i18n("Delete")
                            icon.name: "edit-delete-symbolic"
                            onTriggered: historyModel.remove(card.model.uuid)
                        }
                    }
                }

                PlasmaComponents3.ToolButton {
                    width: 32
                    height: 32
                    visible: card.supportsPin
                    text: card.pinned ? i18n("Unpin") : i18n("Pin")
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    icon.name: card.pinned ? "window-unpin" : "window-pin"
                    icon.width: 16
                    icon.height: 16
                    icon.color: card.pinned ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    onClicked: card.model.starred = !card.pinned
                }
            }
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 20
        visible: historyModel.count === 0
        text: i18n("Clipboard is empty")
        opacity: 0.75
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
