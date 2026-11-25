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
    readonly property alias iconSource: magnifier.colorSource
    readonly property alias hoverIconSource: magnifier.accentSource
    readonly property bool iconIsMask: !magnifier.hasColorSource
    property bool selected: false
    property bool forceHovered: false
    property bool forcePressed: false
    signal triggered()

    readonly property bool showPressed: forcePressed || containsPress
    readonly property bool showHovered: forceHovered || containsMouse || activeFocus
    readonly property bool darkTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.textColor)
                                      === Kirigami.ColorUtils.Light
    readonly property real thickness: height
    readonly property int boxHeight: Math.max(0, Math.min(Math.floor(thickness),
        Math.max(16, Math.round(thickness * 32 / 48))))
    readonly property int boxWidth: Math.round(boxHeight * (styleMode === 1 ? 112 : 220) / 32)
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
        readonly property color restFill: box.darkTheme ? (box.styleMode === 1 ? "#292929" : "#202020") : "#F3F3F3"
        readonly property color hoverFill: box.darkTheme ? "#3B3B3B" : "#E5E5E5"
        readonly property color pressedFill: box.darkTheme ? "#303030" : "#E0E0E0"
        readonly property color selectedFill: box.styleMode === 1 ? "#0078D4" : restFill
        readonly property int inset: Math.round(height * 12 / 32)
        readonly property int iconGap: Math.round(height / 4)
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
            : box.darkTheme ? "#454545" : "#D5D5D5"
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
            width: Math.round(pill.height / 2)
            height: width
            iconName: box.iconName
            accented: box.styleMode === 1 || !box.selected
            foreground: box.selected && box.styleMode === 1 ? "#FFFFFF" : Kirigami.Theme.textColor
        }

        Text {
            id: placeholderLabel
            objectName: "wmSearchPlaceholder"
            visible: pill.showPlaceholder
            anchors.verticalCenter: parent.verticalCenter
            x: pill.mirrored ? (box.styleMode === 1 ? pill.groupLeft : pill.inset) : magnifier.x + magnifier.width + pill.iconGap
            width: box.styleMode === 1 ? pill.labelWidth : Math.max(0, pill.width - 2 * pill.inset - magnifier.width - pill.iconGap)
            horizontalAlignment: Text.AlignLeft
            text: box.styleMode === 1 ? box.text : box.placeholder
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: Kirigami.Theme.defaultFont
            color: box.selected && box.styleMode === 1 ? "#FFFFFF"
                : box.darkTheme ? "#C5FFFFFF" : "#9E000000"
            Accessible.ignored: true
        }
    }
}
