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
    // Windows 26300.9974 TaskbarResources.xbf, ordinary (non-shy) Search.
    // The minimum extents are the preferred baseline. Retain the existing
    // KDE height adaptation until the Windows frame height is established.
    readonly property int boxHeight: Math.max(0, Math.min(Math.floor(thickness), 36,
        Math.max(16, Math.round(thickness * 36 / 42))))
    readonly property real geometryScale: boxHeight / 36
    readonly property int compactContentWidth: 2 * Math.round(22 * geometryScale)
        + Math.round(16 * geometryScale) + Math.round(4 * geometryScale)
        + Math.ceil(compactTextMetrics.advanceWidth)
    readonly property int boxWidth: boxHeight === 0 ? 0 : styleMode === 1
        ? Math.max(Math.round(100 * geometryScale), compactContentWidth)
        : Math.round(220 * geometryScale)
    readonly property int sideMargin: Math.round((styleMode === 1 ? 1 : 2) * geometryScale)
    readonly property int preferredWidth: boxWidth + 2 * sideMargin
    readonly property rect surfaceRect: Qt.rect(pill.x, pill.y, pill.width, pill.height)

    TextMetrics {
        id: compactTextMetrics
        text: box.text
        font.family: Kirigami.Theme.defaultFont.family
        font.pixelSize: Math.max(1, Math.round(16 * box.geometryScale))
        font.weight: Font.Medium
    }

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
        // Wave3 dark brushes have their own original opacity. The light
        // and focused external theme brushes remain KDE approximations.
        readonly property bool compact: box.styleMode === 1
        readonly property color restFill: box.darkTheme
            ? (compact ? "#292929" : Qt.rgba(1, 1, 1, 0.1435)) : "#F3F3F3"
        readonly property color hoverFill: box.darkTheme
            ? (compact ? "#494949" : Qt.rgba(1, 1, 1, 0.1659)) : "#E5E5E5"
        readonly property color selectedFill: compact ? "#0078D4" : (box.darkTheme ? "#202020" : "#FFFFFF")
        // Inactive-pressed and all active Wave3 states share the focused brush.
        readonly property color pressedFill: compact ? (box.darkTheme ? "#353535" : "#E0E0E0") : selectedFill
        readonly property bool focusedSurface: !compact && (box.selected || box.showPressed)
        readonly property real contentScale: height / 36
        readonly property int leadingInset: Math.round((compact ? 22 : 11) * contentScale)
        readonly property int trailingInset: Math.round((compact ? 22 : 16) * contentScale)
        readonly property int iconGap: compact ? Math.round(4 * contentScale)
            : Math.max(0, Math.round(37 * contentScale) - leadingInset - magnifier.width)
        readonly property bool mirrored: box.LayoutMirroring.enabled
        readonly property real availableLabelWidth: Math.max(0,
            width - leadingInset - trailingInset - magnifier.width - iconGap)
        readonly property bool showPlaceholder: availableLabelWidth >= 12 && placeholderLabel.implicitHeight <= height
        readonly property real labelWidth: Math.min(placeholderLabel.implicitWidth, availableLabelWidth)
        readonly property real groupLeft: compact
            ? Math.max(0, Math.round((width - magnifier.width - iconGap - labelWidth) / 2)) : leadingInset

        anchors.centerIn: parent
        width: Math.max(0, Math.min(box.boxWidth, box.width - 2 * box.sideMargin))
        height: Math.min(box.boxHeight, width)
        radius: Math.min(height / 2, 16)
        color: box.selected ? selectedFill : (box.showPressed ? pressedFill : (box.showHovered ? hoverFill : restFill))
        border.width: width > 0 && height > 0 ? 1 : 0
        border.color: box.selected && compact ? selectedFill
            : box.darkTheme ? (focusedSurface ? Qt.rgba(1, 1, 1, 0.18)
                : box.showHovered ? "#555555" : "#4B4B4B") : "#D5D5D5"
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
            width: Math.min(Math.floor(pill.width), Math.round(pill.height * (pill.compact ? 16 : 20) / 36))
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
            x: pill.mirrored ? (pill.compact ? pill.groupLeft : pill.trailingInset)
                : magnifier.x + magnifier.width + pill.iconGap
            width: pill.compact ? pill.labelWidth : pill.availableLabelWidth
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
