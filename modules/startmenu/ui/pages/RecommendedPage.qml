// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../components"

FocusScope {
    id: page
    objectName: "wmStartRecommendedPage"
    property var sourceModel: null
    readonly property alias resultsView: rows
    signal backRequested()
    signal launchRequested(int row)
    signal contextRequested(var entry, int row, real x, real y)

    function reset() {
        rows.currentIndex = -1;
        rows.positionViewAtBeginning();
        backButton.forceActiveFocus(Qt.OtherFocusReason);
    }
    function focusResults() {
        if (rows.count === 0) { backButton.forceActiveFocus(); return; }
        if (rows.currentIndex < 0) rows.currentIndex = 0;
        rows.forceActiveFocus(Qt.TabFocusReason);
    }
    function navigateUp() {
        if (rows.currentIndex <= 0) backButton.forceActiveFocus();
        else { rows.currentIndex--; rows.forceActiveFocus(); }
    }
    function navigateDown() {
        if (!rows.count) return;
        rows.currentIndex = Math.min(rows.count - 1, rows.currentIndex + 1);
        rows.forceActiveFocus();
    }
    function activateCurrent() {
        if (rows.currentIndex >= 0) rows.activateRow(rows.currentIndex);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.preferredHeight: 36

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Recommended")
                font.weight: Font.DemiBold
            }
            AToolButton {
                id: backButton
                objectName: "wmStartRecommendedBack"
                text: i18n("Back")
                iconName: "go-previous-symbolic"
                mirror: true
                flat: true
                linkStyle: true
                onClicked: page.backRequested()
                Keys.onDownPressed: page.focusResults()
            }
        }

        ListView {
            id: rows
            objectName: "wmStartRecommendedRows"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: page.visible ? page.sourceModel : null
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            currentIndex: -1
            highlightMoveDuration: 0

            function activateRow(row) {
                if (row < 0 || row >= count) return;
                currentIndex = row;
                page.launchRequested(row);
            }

            delegate: ListItemDelegate {
                id: entry
                required property int index
                required property var model
                appData: model
                itemIndex: index
                width: rows.width
                height: 54
                iconSize: 28
                // Kicker provides a real file path or application description,
                // but no last-use timestamp. Do not fabricate relative times.
                readonly property bool localFile: String(appData.url || "").startsWith("file:")
                    && !String(appData.url || "").endsWith(".desktop")
                showDescription: localFile
                trailingText: localFile ? "" : String(appData.description || "")
                contextHandler: (data, row, x, y) => {
                    const pos = entry.mapToItem(page, x, y);
                    page.contextRequested(data, row, pos.x, pos.y);
                }
            }

            PlasmaComponents3.ScrollBar.vertical: StartScrollBar { scrolling: rows.moving }
            StartWheelHandler { view: rows; rowHeight: 54 }
            Keys.onReturnPressed: page.activateCurrent()
            Keys.onEnterPressed: page.activateCurrent()
            Keys.onUpPressed: event => {
                if (currentIndex <= 0) { event.accepted = true; backButton.forceActiveFocus(); }
            }
        }
    }
    Keys.onEscapePressed: page.backRequested()
}
