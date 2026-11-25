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
    signal closeRequested()
    property string activeTab: "clipboard"
    property bool emojiPickerEnabled: true
    // The default is the real shared Klipper history. Tests can substitute
    // an isolated model and controller without altering the user's history.
    property Component historySource: Component { Clipboard.HistoryModel {} }
    readonly property var historyModel: historyLoader.item
    property var historyController: historyModel
    readonly property int historyCount: historyModel ? historyModel.count : 0

    Keys.onEscapePressed: page.closeRequested()
    Loader {
        id: historyLoader
        visible: false
        sourceComponent: page.historySource
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 12
        Layout.topMargin: 8
        Layout.preferredHeight: 40
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("Emoji and more")
            font.weight: Font.DemiBold
        }
        PlasmaComponents3.ToolButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: i18n("Close")
            icon.name: "window-close-symbolic"
            icon.width: 18
            icon.height: 18
            onClicked: page.closeRequested()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.preferredHeight: 44
        spacing: 4
        Repeater {
            model: picker.status === Loader.Ready ? [
                {key: "emoji", label: i18n("Emoji"), icon: "preferences-desktop-emoticons", glyph: ""},
                {key: "kaomoji", label: i18n("Kaomoji"), icon: "", glyph: ";-)"},
                {key: "symbols", label: i18n("Symbols"), icon: "", glyph: "Ω+"},
                {key: "clipboard", label: i18n("Clipboard"), icon: "edit-paste", glyph: ""}
            ] : [{key: "clipboard", label: i18n("Clipboard"), icon: "edit-paste", glyph: ""}]
            delegate: QQC2.ToolButton {
                id: tab
                required property var modelData
                readonly property bool selected: page.activeTab === modelData.key
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: modelData.label
                onClicked: page.activeTab = modelData.key
                contentItem: Item {
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        visible: tab.modelData.glyph === ""
                        source: tab.modelData.icon
                        color: Kirigami.Theme.textColor
                        isMask: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: tab.modelData.glyph !== ""
                        text: tab.modelData.glyph
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 17
                    }
                }
                background: Rectangle {
                    radius: 4
                    readonly property color fg: Kirigami.Theme.textColor
                    color: tab.hovered || tab.activeFocus ? Qt.rgba(fg.r, fg.g, fg.b, 0.08) : "transparent"
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 18
                        height: 3
                        radius: 1.5
                        visible: tab.selected
                        color: Kirigami.Theme.highlightColor
                    }
                }
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
        }
    }

    RowLayout {
        visible: page.activeTab === "clipboard"
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        Layout.preferredHeight: 32
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("Clipboard")
            font.weight: Font.DemiBold
        }
        PlasmaComponents3.Button {
            objectName: "wmClipboardClearAll"
            visible: page.historyCount > 0
                && (page.historyModel.starredCount === undefined || page.historyCount > page.historyModel.starredCount)
            text: i18n("Clear all")
            Layout.preferredHeight: 30
            onClicked: page.historyController.clearHistory()
        }
    }

    // Load optional KDE emoji data in isolation; missing modules never
    // disable clipboard history or leave a dead tab.
    Loader {
        id: picker
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: page.activeTab !== "clipboard" && status === Loader.Ready
        active: page.emojiPickerEnabled
        source: "EmojiPicker.qml"
        onLoaded: item.mode = Qt.binding(() => page.activeTab)
    }
    Connections {
        target: picker.item
        function onPicked() { page.itemSelected() }
    }

    ListView {
        id: history
        objectName: "wmClipboardHistory"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        model: page.historyModel
        visible: page.activeTab === "clipboard" && count > 0
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {}

        delegate: Rectangle {
            id: card
            objectName: "wmClipboardCard"
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
                page.historyController.moveToTop(model.uuid);
                page.itemSelected();
            }

            MouseArea {
                id: selectArea
                objectName: "wmClipboardSelect"
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
                objectName: "wmClipboardPreview"
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
                objectName: "wmClipboardText"
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
                            onTriggered: page.historyController.remove(card.model.uuid)
                        }
                    }
                }

                PlasmaComponents3.ToolButton {
                    width: 32
                    height: 32
                    objectName: "wmClipboardPin"
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
        objectName: "wmClipboardEmpty"
        visible: page.activeTab === "clipboard" && page.historyCount === 0
        text: i18n("Clipboard is empty")
        opacity: 0.75
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
