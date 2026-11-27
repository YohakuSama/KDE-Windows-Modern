// SPDX-License-Identifier: GPL-3.0-or-later
// Empty-query search landing page. The existing Kicker models own the
// recommendations, application launch and privacy policy. No online ads.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../code/controlMetrics.js" as ControlMetrics

Item {
    id: home
    objectName: "wmSearchHome"
    property var suggestedModel: null
    property var topAppsModel: null
    property bool showQuickSearches: true
    signal searchRequested(string query)
    signal applicationActivated()
    readonly property color ink: Kirigami.Theme.textColor
    readonly property bool twoColumns: width >= 480 && suggestions.count > 0
        && (showQuickSearches || topApps.count > 0)
    readonly property var quickSearches: [
        { label: i18n("Notification settings"), query: i18n("Notifications") },
        { label: i18n("Sound settings"), query: i18n("Sound") },
        { label: i18n("Bluetooth settings"), query: i18n("Bluetooth") },
        { label: i18n("Display settings"), query: i18n("Display") },
        { label: i18n("Color settings"), query: i18n("Colors") },
        { label: i18n("Search settings"), query: i18n("Search") }
    ]

    function focusFirst() {
        const first = suggestions.itemAtIndex(0) || (showQuickSearches ? quickRepeater.itemAt(0) : null)
            || topApps.itemAtIndex(0)?.children[0];
        if (first) first.forceActiveFocus();
    }

    function launch(modelObject, row) {
        if (modelObject && typeof modelObject.trigger === "function"
                && modelObject.trigger(row, "", null)) {
            applicationActivated();
        }
    }

    component EntryButton: QQC2.Button {
        id: entry
        property var iconSource
        property bool tile: false
        padding: 0
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        background: Rectangle {
            radius: ControlMetrics.controlCornerRadius
            color: Qt.rgba(home.ink.r, home.ink.g, home.ink.b,
                entry.down ? 0.12 : entry.hovered || entry.activeFocus ? 0.09 : entry.tile ? 0.045 : 0)
            border.width: entry.activeFocus ? 1 : 0
            border.color: Kirigami.Theme.highlightColor
            Behavior on color { ColorAnimation { duration: ControlMetrics.microInteractionDuration } }
        }
        contentItem: Item {
            Kirigami.Icon {
                id: entryIcon
                width: entry.tile ? 32 : 24
                height: width
                x: entry.tile ? (parent.width - width) / 2 : 10
                y: entry.tile ? 15 : (parent.height - height) / 2
                source: entry.iconSource || "application-x-executable"
                roundToIconSize: false
                animated: false
            }
            Text {
                x: entry.tile ? 6 : entryIcon.x + entryIcon.width + 10
                y: entry.tile ? entryIcon.y + entryIcon.height + 8 : (parent.height - height) / 2
                width: Math.max(0, parent.width - x - 6)
                text: entry.text
                color: home.ink
                textFormat: Text.PlainText
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: entry.tile ? Text.AlignHCenter : Text.AlignLeft
            }
        }
    }

    Flickable {
        id: viewport
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentGrid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

        GridLayout {
            id: contentGrid
            width: viewport.width
            columns: home.twoColumns ? 2 : 1
            columnSpacing: 16
            rowSpacing: 18

            Text {
                visible: suggestions.count === 0 && topApps.count === 0 && !home.showQuickSearches
                Layout.fillWidth: true
                text: i18n("Type here to search")
                color: home.ink
                opacity: 0.7
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }

            ColumnLayout {
                visible: suggestions.count > 0
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: home.twoColumns ? Math.floor((viewport.width - 16) * 0.4) : viewport.width
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                    text: i18n("Suggested")
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                    color: home.ink
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                ListView {
                    id: suggestions
                    objectName: "wmSearchSuggestions"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(10, count) * 46
                    model: home.suggestedModel
                    interactive: false
                    clip: true
                    currentIndex: -1
                    delegate: EntryButton {
                        required property int index
                        required property var model
                        objectName: "wmSuggested_" + index
                        width: ListView.view.width
                        height: 46
                        visible: index < 10
                        enabled: visible && !model.disabled
                        text: model.display || ""
                        iconSource: model.decoration
                        onClicked: home.launch(home.suggestedModel, index)
                    }
                }
            }

            ColumnLayout {
                visible: home.showQuickSearches || topApps.count > 0
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.preferredWidth: home.twoColumns ? Math.floor((viewport.width - 16) * 0.6) : viewport.width
                Layout.minimumWidth: 0
                spacing: 12
                Text {
                    visible: home.showQuickSearches
                    text: i18n("Quick searches")
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                    color: home.ink
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: home.showQuickSearches
                    implicitHeight: chips.implicitHeight + 24
                    objectName: "wmSearchQuickSearchSurface"
                    radius: ControlMetrics.cardSurfaceRadius
                    color: Qt.rgba(home.ink.r, home.ink.g, home.ink.b, 0.045)
                    Flow {
                        id: chips
                        x: 12
                        y: 12
                        width: Math.max(1, parent.width - 24)
                        spacing: 8
                        Repeater {
                            id: quickRepeater
                            model: home.showQuickSearches ? home.quickSearches : []
                            delegate: QQC2.Button {
                                id: chip
                                required property int index
                                required property var modelData
                                objectName: "wmQuickSearch_" + index
                                width: Math.max(1, Math.min(chips.width, implicitWidth))
                                implicitWidth: chipLabel.implicitWidth + 24
                                implicitHeight: 32
                                height: implicitHeight
                                padding: 0
                                text: modelData.label
                                hoverEnabled: true
                                focusPolicy: Qt.StrongFocus
                                Accessible.name: text
                                background: Rectangle {
                                    radius: height / 2
                                    color: Qt.rgba(home.ink.r, home.ink.g, home.ink.b,
                                        chip.down ? 0.16 : chip.hovered || chip.activeFocus ? 0.12 : 0.06)
                                    border.width: chip.activeFocus ? 1 : 0
                                    border.color: Kirigami.Theme.highlightColor
                                    Behavior on color { ColorAnimation { duration: ControlMetrics.microInteractionDuration } }
                                }
                                contentItem: Text {
                                    id: chipLabel
                                    text: chip.text
                                    color: home.ink
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: home.searchRequested(modelData.query)
                            }
                        }
                    }
                }
                Text {
                    visible: topApps.count > 0
                    Layout.topMargin: 8
                    text: i18n("Top apps")
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                    color: home.ink
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                GridView {
                    id: topApps
                    objectName: "wmSearchTopApps"
                    readonly property int columns: width >= 240 ? 3 : width >= 140 ? 2 : 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.ceil(Math.min(count, 6) / columns) * cellHeight
                    visible: count > 0
                    cellWidth: Math.max(1, Math.floor(width / columns))
                    cellHeight: 100
                    interactive: false
                    clip: true
                    currentIndex: -1
                    model: home.topAppsModel
                    delegate: Item {
                        required property int index
                        required property var model
                        width: GridView.view.cellWidth
                        height: GridView.view.cellHeight
                        visible: index < 6
                        id: tileDelegate
                        EntryButton {
                            anchors.fill: parent
                            anchors.margins: 3
                            objectName: "wmTopApp_" + tileDelegate.index
                            enabled: tileDelegate.visible && !tileDelegate.model.disabled
                            tile: true
                            text: tileDelegate.model.display || ""
                            iconSource: tileDelegate.model.decoration
                            onClicked: home.launch(home.topAppsModel, tileDelegate.index)
                        }
                    }
                }
            }
        }
    }
}
