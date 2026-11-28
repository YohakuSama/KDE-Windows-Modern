// SPDX-License-Identifier: GPL-3.0-or-later
// The emoji data and copy helper are provided by Plasma's own emoji picker.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.emoji as Emoji
import "../lib" as Lib
import "../js/controlMetrics.js" as ControlMetrics

ColumnLayout {
    id: picker
    property string mode: "emoji"
    signal picked()
    spacing: 8

    Emoji.EmojiModel { id: emojis }
    Emoji.CategoryModelFilter {
        id: emojiFilter
        category: categoryBox.currentIndex > 0 ? emojis.categories[categoryBox.currentIndex - 1] : "All"
        sourceModel: Emoji.SearchModelFilter {
            sourceModel: emojis
            search: searchField.text
        }
    }

    readonly property var kaomojiGroups: [
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Happy"), entries: ["(^_^)", "(＾▽＾)", "(≧▽≦)", "(✿◠‿◠)", "(´▽`ʃ♡ƪ)", "(o^▽^o)", "(⌒‿⌒)", "(•‿•)"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Sad"), entries: ["(T_T)", "(；ω；)", "(╥﹏╥)", "(｡•́︿•̀｡)", "(ಥ_ಥ)", "(╯︵╰,)"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Love"), entries: ["(♥‿♥)", "(♡˙︶˙♡)", "(´｡• ᵕ •｡`) ♡", "(づ￣ ³￣)づ", "(っ˘з(˘⌣˘ )"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Other"), entries: ["¯\\_(ツ)_/¯", "(¬_¬)", "(・_・;)", "(・∀・)", "(ง •̀_•́)ง", "(╯°□°）╯︵ ┻━┻", "ʕ•ᴥ•ʔ"]}
    ]
    readonly property var symbolGroups: [
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Punctuation"), entries: ["…","·","•","‧","«","»","‹","›","‘","’","“","”","¿","¡","※","§","¶","†","‡"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Currency"), entries: ["¥","￥","€","£","$","¢","₩","₹","₽","₿","₺","₫","₴","₱","₪","฿"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Mathematics"), entries: ["±","×","÷","≠","≈","≤","≥","∞","√","∑","∏","∫","∂","∆","∇","π","°","∠","∈","∉","⊂","∪","∩","∝","≡","∴","∵","‰"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Arrows"), entries: ["←","↑","→","↓","↔","↕","↖","↗","↘","↙","↩","↪","⇐","⇒","⇔","⟶","⟵"]},
        {name: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Other"), entries: ["©","®","™","℠","℃","℉","✓","✔","✕","✖","★","☆","♠","♣","♥","♦","♩","♪","♫","♬","○","●","□","■","△","▲","◇","◆"]}
    ]
    readonly property var groups: mode === "kaomoji" ? kaomojiGroups : symbolGroups
    readonly property var textEntries: {
        const available = groups || [];
        const entries = localCategory.currentIndex > 0
            ? (available[localCategory.currentIndex - 1]?.entries || [])
            : available.reduce((all, group) => all.concat(group.entries), []);
        return searchField.text ? entries.filter(entry => entry.includes(searchField.text)) : entries;
    }
    onModeChanged: {
        searchField.clear();
        categoryBox.currentIndex = 0;
        localCategory.currentIndex = 0;
    }

    function copy(value) {
        if (!value) return;
        Emoji.CopyHelper.copyTextToClipboard(value);
        picker.picked();
    }

    QQC2.TextField {
        id: searchField
        objectName: "wmEmojiSearch"
        Layout.fillWidth: true
        Layout.minimumHeight: ControlMetrics.menuItemMinimumHeight
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 8
        placeholderText: picker.mode === "emoji" ? i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Search emoji") : i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "Search")
        selectByMouse: true
    }

    QQC2.ComboBox {
        id: categoryBox
        visible: picker.mode === "emoji"
        Layout.fillWidth: true
        Layout.minimumHeight: ControlMetrics.menuItemMinimumHeight
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        model: [i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "All")].concat(emojis.categories.map(category =>
            i18ndc("org.kde.plasma.emojier", "Emoji Category", category)))
    }

    QQC2.ComboBox {
        id: localCategory
        visible: picker.mode === "kaomoji" || picker.mode === "symbols"
        Layout.fillWidth: true
        Layout.minimumHeight: ControlMetrics.menuItemMinimumHeight
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        model: [i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "All")].concat((picker.groups || []).map(group => group.name))
    }

    GridView {
        id: emojiGrid
        objectName: "wmEmojiGrid"
        visible: picker.mode === "emoji"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        model: emojiFilter
        clip: true
        cellWidth: width / Math.max(1, Math.floor(width / 48))
        cellHeight: 48
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        HoverHandler { id: emojiHover }
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {
            viewportHovered: emojiHover.hovered
            scrolling: emojiGrid.moving || emojiGrid.flicking
        }
        delegate: QQC2.ItemDelegate {
            id: emojiCell
            required property var model
            width: emojiGrid.cellWidth
            height: emojiGrid.cellHeight
            text: model.display
            background: Rectangle {
                radius: ControlMetrics.controlCornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, emojiCell.down ? 0.12
                        : emojiCell.hovered || emojiCell.activeFocus ? 0.08 : 0)
            }
            contentItem: Text {
                text: emojiCell.text
                color: Kirigami.Theme.textColor
                font.family: "emoji"
                font.pixelSize: 26
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Accessible.name: model.toolTip
            QQC2.ToolTip.text: model.toolTip
            QQC2.ToolTip.visible: hovered
            onClicked: picker.copy(text)
        }
        QQC2.Label {
            anchors.centerIn: parent
            visible: emojiGrid.count === 0
            text: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "No matching emoji found")
            textFormat: Text.PlainText
        }
    }

    GridView {
        id: localGrid
        objectName: "wmSymbolGrid"
        visible: picker.mode === "kaomoji" || picker.mode === "symbols"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        model: picker.textEntries
        clip: true
        cellWidth: width / Math.max(1, Math.floor(width / (picker.mode === "kaomoji" ? 132 : 44)))
        cellHeight: picker.mode === "kaomoji" ? 44 : 40
        boundsBehavior: Flickable.StopAtBounds
        HoverHandler { id: localHover }
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {
            viewportHovered: localHover.hovered
            scrolling: localGrid.moving || localGrid.flicking
        }
        delegate: QQC2.ItemDelegate {
            id: textCell
            required property string modelData
            width: localGrid.cellWidth
            height: localGrid.cellHeight
            text: modelData
            background: Rectangle {
                radius: ControlMetrics.controlCornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, textCell.down ? 0.12
                        : textCell.hovered || textCell.activeFocus ? 0.08 : 0)
            }
            contentItem: Text {
                text: textCell.text
                color: Kirigami.Theme.textColor
                font.pixelSize: picker.mode === "kaomoji" ? 14 : 21
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: picker.copy(text)
        }
        QQC2.Label {
            anchors.centerIn: parent
            visible: localGrid.count === 0
            text: i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "No results")
            textFormat: Text.PlainText
        }
    }
}
