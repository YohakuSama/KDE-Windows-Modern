/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Shared Start search input; layout and power actions belong to the shell.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme

RowLayout {
    id: searchBox

    spacing: Kirigami.Units.largeSpacing
    height: implicitHeight

    property alias searchText: searchFieldInput.text

    signal searchFocusResults
    signal searchNavUp
    signal searchNavDown
    signal searchActivateFirstResult
    signal searchEscapePressed
    signal tabOut

    function focusSearch() {
        searchFieldInput.forceActiveFocus();
    }

    Keys.onTabPressed: event => {
        event.accepted = true;
        tabOut();
    }

    // ── Search field (fills) ───────────────────────────────────────────
    PlasmaComponents3.TextField {
        id: searchFieldInput
        Layout.fillWidth: true
        focus: true
        placeholderText: i18n("Search for apps, settings, and files")
        topPadding: 8
        bottomPadding: 8
        leftPadding: Kirigami.Units.gridUnit + Kirigami.Units.iconSizes.small
        font.pointSize: Kirigami.Theme.defaultFont.pointSize

        background: Rectangle {
            color: Kirigami.Theme.backgroundColor
            radius: Kirigami.Units.smallSpacing * 3
            border.width: 1
            border.color: searchFieldInput.activeFocus ? Kirigami.Theme.highlightColor
                : Qt.rgba(Kirigami.Theme.textColor.r,
                          Kirigami.Theme.textColor.g,
                          Kirigami.Theme.textColor.b, Theme.fieldBorderOpacity)
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }

        // No onTextChanged here: searchText aliases this text, so QML already
        // emits searchTextChanged. Emitting it again ran every search twice.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                searchBox.searchEscapePressed();
                return;
            }
            if (event.key === Qt.Key_Down) {
                event.accepted = true;
                searchBox.searchNavDown();
                return;
            }
            if (event.key === Qt.Key_Up) {
                event.accepted = true;
                searchBox.searchNavUp();
                return;
            }
            if (event.key === Qt.Key_Tab) {
                event.accepted = true;
                searchBox.searchFocusResults();
                return;
            }
        }
        Keys.onReturnPressed: searchBox.searchActivateFirstResult()
        Keys.onEnterPressed: searchBox.searchActivateFirstResult()

        Kirigami.Icon {
            source: "search"
            anchors.left: searchFieldInput.left
            anchors.verticalCenter: searchFieldInput.verticalCenter
            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
            height: Kirigami.Units.iconSizes.small
            width: height
        }
    }

}
