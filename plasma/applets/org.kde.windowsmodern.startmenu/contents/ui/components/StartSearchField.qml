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
        Layout.preferredHeight: 32
        topPadding: 4
        bottomPadding: 4
        leftPadding: 36
        font.pixelSize: 14

        background: Rectangle {
            color: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
                ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.68)
            radius: height / 2
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, searchFieldInput.activeFocus ? 0.15 : 0.08)
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }

        // No onTextChanged here: searchText aliases this text, so QML already
        // emits searchTextChanged. Emitting it again ran every search twice.
        Keys.onPressed: event => {
            // Chinese/Japanese/Korean input methods own navigation and
            // confirmation while their candidate/composition UI is active.
            if (searchFieldInput.inputMethodComposing)
                return;
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
        Keys.onReturnPressed: event => {
            if (searchFieldInput.inputMethodComposing) { event.accepted = false; return; }
            searchBox.searchActivateFirstResult();
        }
        Keys.onEnterPressed: event => {
            if (searchFieldInput.inputMethodComposing) { event.accepted = false; return; }
            searchBox.searchActivateFirstResult();
        }

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
