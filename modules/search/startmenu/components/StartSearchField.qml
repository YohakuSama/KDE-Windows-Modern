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

import "../code/controlMetrics.js" as ControlMetrics

RowLayout {
    id: searchBox

    spacing: Kirigami.Units.largeSpacing
    height: implicitHeight

    property alias searchText: searchFieldInput.text
    readonly property int cursorPosition: searchFieldInput.cursorPosition
    readonly property bool editorFocused: searchFieldInput.activeFocus
    property bool mirrorInPanel: false
    readonly property bool composing: searchFieldInput.inputMethodComposing
    property bool searchMode: false
    signal searchRequested

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
        objectName: "wmStartSearchInput"
        Accessible.name: searchBox.mirrorInPanel ? i18n("Search query")
            : searchBox.searchMode ? i18n("Type here to search") : placeholderText
        Layout.fillWidth: true
        focus: true
        placeholderText: i18n("Search for apps, settings, and files")
        hoverEnabled: true
        TapHandler {
            gesturePolicy: TapHandler.DragThreshold
            onTapped: searchBox.searchRequested()
        }
        // The leading glyph and text inset must move together in RTL.
        // Use the system font and keep a 32px minimum logical control.
        readonly property bool layoutMirrored: LayoutMirroring.enabled
        readonly property int leadingInset: 36
        readonly property int trailingInset: 12
        Layout.preferredHeight: Math.max(32, Math.ceil(editorMetrics.height) + topPadding + bottomPadding)
        topPadding: 4
        bottomPadding: 4
        leftPadding: layoutMirrored ? trailingInset : leadingInset
        rightPadding: layoutMirrored ? leadingInset : trailingInset
        font: Kirigami.Theme.defaultFont
        FontMetrics { id: editorMetrics; font: searchFieldInput.font }

        background: Rectangle {
            readonly property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
            color: dark
                ? (searchFieldInput.hovered && !searchBox.searchMode ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.22))
                : (searchFieldInput.hovered && !searchBox.searchMode ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.68))
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? ControlMetrics.microInteractionDuration : 0 } }
            radius: height / 2
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, searchFieldInput.activeFocus ? 0.15 : 0.08)
            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration > 0 ? ControlMetrics.microInteractionDuration : 0 } }
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

        SearchGlyph {
            anchors.verticalCenter: searchFieldInput.verticalCenter
            x: searchFieldInput.layoutMirrored ? searchFieldInput.width - 12 - width : 12
            height: Math.max(0, Math.min(18, searchFieldInput.height, searchFieldInput.width - 24))
            width: height
            accented: false
        }
    }

}
