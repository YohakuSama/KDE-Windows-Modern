// SPDX-License-Identifier: GPL-3.0-or-later
// The emoji data and copy helper are provided by Plasma's own emoji picker.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.emoji as Emoji
import "../lib" as Lib

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
        {name: i18n("Happy"), entries: ["(^_^)", "(＾▽＾)", "(≧▽≦)", "(✿◠‿◠)", "(´▽`ʃ♡ƪ)", "(o^▽^o)", "(⌒‿⌒)", "(•‿•)"]},
        {name: i18n("Sad"), entries: ["(T_T)", "(；ω；)", "(╥﹏╥)", "(｡•́︿•̀｡)", "(ಥ_ಥ)", "(╯︵╰,)"]},
        {name: i18n("Love"), entries: ["(♥‿♥)", "(♡˙︶˙♡)", "(´｡• ᵕ •｡`) ♡", "(づ￣ ³￣)づ", "(っ˘з(˘⌣˘ )"]},
        {name: i18n("Other"), entries: ["¯\\_(ツ)_/¯", "(¬_¬)", "(・_・;)", "(・∀・)", "(ง •̀_•́)ง", "(╯°□°）╯︵ ┻━┻", "ʕ•ᴥ•ʔ"]}
    ]
    readonly property var symbolGroups: [
        {name: i18n("Punctuation"), entries: ["…","·","•","‧","«","»","‹","›","‘","’","“","”","¿","¡","※","§","¶","†","‡"]},
        {name: i18n("Currency"), entries: ["¥","￥","€","£","$","¢","₩","₹","₽","₿","₺","₫","₴","₱","₪","฿"]},
        {name: i18n("Mathematics"), entries: ["±","×","÷","≠","≈","≤","≥","∞","√","∑","∏","∫","∂","∆","∇","π","°","∠","∈","∉","⊂","∪","∩","∝","≡","∴","∵","‰"]},
        {name: i18n("Arrows"), entries: ["←","↑","→","↓","↔","↕","↖","↗","↘","↙","↩","↪","⇐","⇒","⇔","⟶","⟵"]},
        {name: i18n("Other"), entries: ["©","®","™","℠","℃","℉","✓","✔","✕","✖","★","☆","♠","♣","♥","♦","♩","♪","♫","♬","○","●","□","■","△","▲","◇","◆"]}
    ]
    readonly property var groups: mode === "kaomoji" ? kaomojiGroups : symbolGroups
    readonly property var textEntries: {
        const entries = localCategory.currentIndex > 0
            ? (groups[localCategory.currentIndex - 1]?.entries || [])
            : groups.reduce((all, group) => all.concat(group.entries), []);
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
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 8
        placeholderText: picker.mode === "emoji" ? i18n("Search emoji") : i18n("Search")
        selectByMouse: true
    }

    QQC2.ComboBox {
        id: categoryBox
        visible: picker.mode === "emoji"
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        model: [i18n("All")].concat(emojis.categories.map(category =>
            i18ndc("org.kde.plasma.emojier", "Emoji Category", category)))
    }

    QQC2.ComboBox {
        id: localCategory
        visible: picker.mode === "kaomoji" || picker.mode === "symbols"
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        model: [i18n("All")].concat(picker.groups.map(group => group.name))
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
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {}
        delegate: QQC2.ItemDelegate {
            id: emojiCell
            required property var model
            width: emojiGrid.cellWidth
            height: emojiGrid.cellHeight
            text: model.display
            contentItem: Text {
                text: emojiCell.text
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
            text: i18n("No matching emoji found")
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
        QQC2.ScrollBar.vertical: Lib.FluentScrollBar {}
        delegate: QQC2.ItemDelegate {
            id: textCell
            required property string modelData
            width: localGrid.cellWidth
            height: localGrid.cellHeight
            text: modelData
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
            text: i18n("No results")
        }
    }
}
