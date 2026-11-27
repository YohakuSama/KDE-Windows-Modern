// SPDX-License-Identifier: GPL-3.0-or-later
// Use the real Klipper history; moveToTop preserves the complete MIME payload.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.private.clipboard as Clipboard
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../lib" as Lib
import "../js/colorType.js" as ColorType
import "../js/controlMetrics.js" as ControlMetrics

ColumnLayout {
    id: page
    spacing: 0
    property Component footer: null
    signal back()
    signal itemSelected()
    signal closeRequested()
    property string activeTab: "clipboard"
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor,
        Qt.color(ColorType.cardFill(dark, false)), 4.5)
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
            text: picker.status === Loader.Ready ? i18n("Emoji and more") : i18n("Clipboard history")
            font.weight: Font.DemiBold
        }
        NativeToolButton {
            objectName: "wmClipboardClose"
            nativeRole: "window-close-symbolic"
            Layout.preferredWidth: nativeIcon.length > 0 ? 32 : implicitWidth
            Layout.preferredHeight: 32
            text: i18n("Close")
            icon.width: 18
            icon.height: 18
            onClicked: page.closeRequested()
        }
    }

    RowLayout {
        visible: picker.status === Loader.Ready
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
                    NativeGlyph {
                        id: tabGlyph
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        visible: tab.modelData.glyph === "" && nativeSource.length > 0
                        roleName: tab.modelData.icon
                    }
                    Text {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 4)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        visible: tab.modelData.glyph !== "" || tabGlyph.nativeSource.length === 0
                        text: tab.modelData.glyph || tab.modelData.label
                        textFormat: Text.PlainText
                        color: Kirigami.Theme.textColor
                        font.pixelSize: tab.modelData.glyph !== "" ? 17 : 12
                    }
                }
                background: Rectangle {
                    radius: ControlMetrics.controlCornerRadius
                    readonly property color fg: Kirigami.Theme.textColor
                    color: tab.hovered || tab.activeFocus ? Qt.rgba(fg.r, fg.g, fg.b, 0.08) : "transparent"
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 18
                        height: 3
                        radius: 1.5
                        visible: tab.selected
                        color: page.accent
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
            visible: picker.status === Loader.Ready
            text: i18n("Clipboard")
            font.weight: Font.DemiBold
        }
        Item { Layout.fillWidth: true; visible: picker.status !== Loader.Ready }
        PlasmaComponents3.Button {
            objectName: "wmClipboardClearAll"
            visible: page.historyCount > 0
                && (page.historyModel.starredCount === undefined || page.historyCount > page.historyModel.starredCount)
            text: i18n("Clear all")
            Layout.preferredHeight: 30
            enabled: !!page.historyController
            onClicked: if (page.historyController) page.historyController.clearHistory()
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
        onStatusChanged: if (status !== Loader.Ready && page.activeTab !== "clipboard") page.activeTab = "clipboard"
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
        HoverHandler { id: historyHover }
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {
            objectName: "wmClipboardScrollBar"
            dark: page.dark
            viewportHovered: historyHover.hovered
            scrolling: history.moving || history.flicking
        }

        delegate: Rectangle {
            id: card
            objectName: "wmClipboardCard"
            required property var model
            readonly property string itemUuid: String(model?.uuid || "")
            readonly property bool isImage: model.type === 4
            readonly property bool supportsPin: model.starred !== undefined
            readonly property bool pinned: supportsPin && model.starred
            readonly property color fg: Kirigami.Theme.textColor
            width: Math.max(1, history.width - (history.contentHeight > history.height ? 16 : 0))
            height: isImage ? 108 : 76
            radius: 6
            color: ColorType.rowFill(page.dark, true, selectArea.containsMouse, selectArea.containsPress)
            border.width: 1
            border.color: selectArea.activeFocus ? page.accent
                : ColorType.divider(page.dark)

            function selectItem() {
                if (!itemUuid || !page.historyController) return;
                page.historyController.moveToTop(itemUuid);
                page.itemSelected();
            }

            MouseArea {
                id: selectArea
                objectName: "wmClipboardSelect"
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: actionsColumn.left
                z: 1
                hoverEnabled: true
                activeFocusOnTab: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: card.isImage ? i18n("Image") : String(card.model.display || "")
                Accessible.onPressAction: card.selectItem()
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) card.selectItem(); }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat) card.selectItem(); }
                Keys.onSpacePressed: event => { if (!event.isAutoRepeat) card.selectItem(); }
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
                width: Math.max(1, Math.min(card.width - actionsColumn.width - 30, 220))
                source: card.isImage ? card.model.decoration : ""
                sourceSize.width: 300
                sourceSize.height: 200
                asynchronous: true
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
                visible: !card.isImage || preview.status !== Image.Ready
                text: card.isImage ? i18n("Image") : String(card.model.display || "")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 3
            }

            Column {
                id: actionsColumn
                z: 2
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.top: parent.top
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: Math.min(Math.max(0, card.width - 20), Math.max(32,
                    moreButton.nativeIcon.length > 0 ? 32 : Math.min(112, moreButton.implicitWidth),
                    pinButton.visible && pinButton.nativeIcon.length === 0 ? Math.min(112, pinButton.implicitWidth) : 32))
                spacing: Math.max(0, height - 64)

                NativeToolButton {
                    id: moreButton
                    objectName: "wmClipboardMore"
                    nativeRole: "view-more-symbolic"
                    width: actionsColumn.width
                    height: 32
                    text: i18n("More actions")
                    icon.width: 16
                    icon.height: 16
                    enabled: !!page.historyController && card.itemUuid.length > 0
                    onClicked: actions.opened ? actions.close() : actions.open()
                    QQC2.Menu {
                        id: actions
                        objectName: "wmClipboardActions"
                        property string targetUuid: ""
                        // Keep the captured ID through the close animation:
                        // Qt may close the menu before delivering triggered.
                        onAboutToShow: targetUuid = card.itemUuid
                        parent: moreButton
                        popupType: QQC2.Popup.Item
                        x: moreButton.width - width
                        y: moreButton.height + 4
                        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
                        NativeMenuItem {
                            objectName: "wmClipboardDelete"
                            text: i18n("Delete")
                            nativeRole: "edit-delete-symbolic"
                            enabled: !!page.historyController && actions.targetUuid.length > 0
                                && actions.targetUuid === card.itemUuid
                            onTriggered: {
                                if (page.historyController && actions.targetUuid
                                    && actions.targetUuid === card.itemUuid)
                                    page.historyController.remove(actions.targetUuid);
                            }
                        }
                    }
                }

                NativeToolButton {
                    id: pinButton
                    nativeRole: card.pinned ? "window-unpin" : "window-pin"
                    width: actionsColumn.width
                    height: 32
                    objectName: "wmClipboardPin"
                    visible: card.supportsPin
                    text: card.pinned ? i18n("Unpin") : i18n("Pin")
                    icon.width: 16
                    icon.height: 16
                    icon.color: card.pinned ? page.accent : Kirigami.Theme.textColor
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
