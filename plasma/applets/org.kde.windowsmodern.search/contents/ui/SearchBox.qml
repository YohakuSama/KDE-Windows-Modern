/*
    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later

    Windows 11 taskbar Search surfaces:
    0 = full search box, 1 = compact icon-and-label pill.
    Icon-only mode uses the shared taskbar button.
*/
import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: box
    property string iconName: "search"
    property int styleMode: 0
    property string text
    property string description
    property string placeholder
    readonly property alias iconSource: magnifier.accentSource
    readonly property alias hoverIconSource: magnifier.colorSource
    readonly property bool iconIsMask: magnifier.offIsMask
    readonly property bool hoverIconIsMask: magnifier.onIsMask
    property bool selected: false
    property string queryText: ""
    property int queryCursor: 0
    property bool queryFocused: false
    readonly property bool showQuery: selected && styleMode === 0 && queryText.length > 0
    property bool forceHovered: false
    property bool forcePressed: false
    signal triggered()

    readonly property bool showPressed: forcePressed || containsPress
    readonly property bool showHovered: forceHovered || containsMouse || activeFocus
    readonly property bool darkTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.textColor)
                                      === Kirigami.ColorUtils.Light
    readonly property real thickness: height
    // Reference at 150%: about 370 x 54 physical px, or 248 x 36 logical px.
    // Plasma gives an inset cell, not the entire panel thickness.
    readonly property int boxHeight: Math.max(0, Math.min(Math.floor(thickness), 36,
        Math.max(16, Math.round(thickness * 36 / 42))))
    readonly property int boxWidth: Math.round(boxHeight * (styleMode === 1 ? 112 : 248) / 36)
    readonly property int sideMargin: Math.max(0, Math.round((thickness - boxHeight) / 4))
    readonly property int preferredWidth: boxWidth + 2 * sideMargin

    hoverEnabled: true
    activeFocusOnTab: true
    onClicked: box.triggered()

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            if (!event.isAutoRepeat) box.triggered();
            event.accepted = true;
            break;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: description
    Accessible.onPressAction: box.triggered()

    Rectangle {
        id: pill
        objectName: "wmSearchPill"
        readonly property color restFill: box.darkTheme ? (box.styleMode === 1 ? "#292929" : "#3D3D3D") : "#F3F3F3"
        readonly property color hoverFill: box.darkTheme ? "#494949" : "#E5E5E5"
        readonly property color pressedFill: box.darkTheme ? "#353535" : "#E0E0E0"
        readonly property color selectedFill: box.styleMode === 1 ? "#0078D4" : (box.darkTheme ? "#202020" : "#FFFFFF")
        readonly property int inset: Math.round(height * 14 / 36)
        readonly property int iconGap: Math.round(height * 9 / 36)
        readonly property bool mirrored: box.LayoutMirroring.enabled
        readonly property bool showPlaceholder: width >= 2 * inset + magnifier.width + iconGap + 12
            && placeholderLabel.implicitHeight <= height
        readonly property real labelWidth: Math.max(0, Math.min(placeholderLabel.implicitWidth,
            width - 2 * inset - magnifier.width - iconGap))
        readonly property real groupLeft: box.styleMode === 1 ? Math.round((width - magnifier.width - iconGap - labelWidth) / 2) : inset

        anchors.centerIn: parent
        width: Math.max(0, Math.min(box.boxWidth, box.width - 2 * box.sideMargin))
        height: Math.min(box.boxHeight, width)
        radius: height / 2
        color: box.selected ? selectedFill : (box.showPressed ? pressedFill : (box.showHovered ? hoverFill : restFill))
        border.width: 1
        border.color: box.selected && box.styleMode === 1 ? selectedFill
            : box.darkTheme ? (box.showHovered ? "#555555" : "#4B4B4B") : "#D5D5D5"
        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        SearchGlyph {
            id: magnifier
            objectName: "searchBoxIcon"
            anchors.verticalCenter: parent.verticalCenter
            x: pill.showPlaceholder ? (pill.mirrored ? pill.width - pill.groupLeft - width : pill.groupLeft)
                                    : Math.round((pill.width - width) / 2)
            width: Math.round(pill.height * 20 / 36)
            height: width
            iconName: box.iconName
            accented: box.styleMode === 1 && box.selected || !(box.selected || box.showHovered)
            forceMask: box.styleMode === 1 && box.selected
            foreground: box.selected && box.styleMode === 1 ? "#FFFFFF" : box.darkTheme ? "#D0D0D0" : "#5D5D5D"
        }

        Text {
            id: placeholderLabel
            objectName: "wmSearchPlaceholder"
            visible: pill.showPlaceholder
            anchors.verticalCenter: parent.verticalCenter
            x: pill.mirrored ? (box.styleMode === 1 ? pill.groupLeft : pill.inset) : magnifier.x + magnifier.width + pill.iconGap
            width: box.styleMode === 1 ? pill.labelWidth : Math.max(0, pill.width - 2 * pill.inset - magnifier.width - pill.iconGap)
            horizontalAlignment: Text.AlignLeft
            text: box.styleMode === 1 ? box.text : box.showQuery ? box.queryText : box.placeholder
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Math.max(1, Math.round(pill.height * 16 / 36))
            font.weight: Font.Medium
            color: box.selected && box.styleMode === 1 ? "#FFFFFF"
                : box.showQuery ? (box.darkTheme ? "#FFFFFF" : "#1B1B1B")
                : box.darkTheme ? "#D0D0D0" : "#5D5D5D"
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            Accessible.ignored: !box.showQuery
        }
        TextMetrics {
            id: caretMetrics
            font: placeholderLabel.font
            text: box.queryText.substring(0, Math.max(0, box.queryCursor))
        }
        Rectangle {
            id: queryCaret
            objectName: "wmTaskbarSearchCaret"
            visible: box.selected && box.styleMode === 0 && box.queryFocused && placeholderLabel.visible
            x: placeholderLabel.x + Math.min(Math.max(0, placeholderLabel.width - 1),
                Math.round(caretMetrics.advanceWidth))
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Math.round(placeholderLabel.font.pixelSize * 1.05)
            color: box.darkTheme ? "#D0D0D0" : "#1B1B1B"
        }
    }
}
