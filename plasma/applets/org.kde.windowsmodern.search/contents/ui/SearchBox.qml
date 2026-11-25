/*
    SPDX-FileCopyrightText: 2026 Jeysef <jeysef@users.noreply.github.com>
    SPDX-License-Identifier: GPL-3.0-or-later

    The Windows 11 taskbar search box: a pill with a magnifier and the
    placeholder "Search". Clicking it opens Start with its search field
    focused; it takes no typing itself.

    Geometry, in a 48 px taskbar (scaled with the panel's thickness):
    - 220 x 32 px. The width is the stock box's: Windhawk taskbar themes
      select the default box as SearchButtonRootGrid[Width=220]
      (github.com/ramensoftware/windows-11-taskbar-styling-guide). The
      height is the 32 px they give the matching search background; 2026
      Insider builds (26300.8935) add 4 px to it, not shipped yet.
    - Fully rounded ends, as the guide's "pill-shaped" search background.
    - Glyph 16 px, 12 px in from the left edge, 8 px before the text.
    Colours are WinUI's (microsoft-ui-xaml Common_themeresources_any.xaml):
    fill ControlFillColorDefault, hover ControlFillColorSecondary, pressed
    ControlFillColorTertiary; 1 px ControlStrokeColorDefault border;
    placeholder TextFillColorSecondary.

    No Plasma imports, so tests can render it headless.
*/

import QtQuick

import org.kde.kirigami as Kirigami

MouseArea {
    id: box

    property string iconName: "edit-find-symbolic"
    property string text
    property string description
    property string placeholder
    readonly property alias iconSource: magnifier.resolvedSource

    // Preview/test hooks: draw a state without a pointer.
    property bool forceHovered: false
    property bool forcePressed: false

    signal triggered()

    readonly property bool showPressed: forcePressed || containsPress
    readonly property bool showHovered: forceHovered || containsMouse || activeFocus

    readonly property bool darkTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.textColor)
                                      === Kirigami.ColorUtils.Light

    // Everything follows the panel's thickness; 48 px is the reference.
    readonly property real thickness: height
    readonly property int boxHeight: Math.max(0, Math.min(Math.floor(thickness), Math.max(16, Math.round(thickness * 32 / 48))))
    readonly property int boxWidth: Math.round(boxHeight * 220 / 32)
    // The gap to the neighbouring buttons on each side.
    readonly property int sideMargin: Math.max(0, Math.round((thickness - boxHeight) / 4))
    // What the applet asks the panel for.
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

        // WinUI ControlFillColor{Default,Secondary,Tertiary} and
        // ControlStrokeColorDefault, dark / light.
        // Owner's Windows 11 reference: quiet outlined rest, visibly
        // filled hover and a reduced fill on press.
        readonly property color restFill: box.darkTheme ? Qt.rgba(1, 1, 1, 0.02) : Qt.rgba(1, 1, 1, 0.55)
        readonly property color hoverFill: box.darkTheme ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.9)
        readonly property color pressedFill: box.darkTheme ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.68)

        objectName: "wmSearchPill"
        readonly property int inset: Math.round(height * 12 / 32)
        readonly property int iconGap: Math.round(height / 4)
        readonly property bool mirrored: box.LayoutMirroring.enabled
        readonly property bool showPlaceholder: width >= 2 * inset + magnifier.width + iconGap + 12
            && placeholderLabel.implicitHeight <= height
        anchors.centerIn: parent
        width: Math.max(0, Math.min(box.boxWidth, box.width - 2 * box.sideMargin))
        height: Math.min(box.boxHeight, width)
        radius: height / 2
        color: box.showPressed ? pressedFill : (box.showHovered ? hoverFill : restFill)
        border.width: 1
        border.color: box.darkTheme ? Qt.rgba(1, 1, 1, 0x12 / 255) : Qt.rgba(0, 0, 0, 0x0F / 255)

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        SearchGlyph {
            id: magnifier
            objectName: "searchBoxIcon"

            anchors.verticalCenter: parent.verticalCenter
            x: pill.showPlaceholder ? (pill.mirrored ? pill.width - pill.inset - width : pill.inset)
                                    : Math.round((pill.width - width) / 2)
            width: Math.round(pill.height / 2)
            height: width
            iconName: box.iconName
        }

        Text {
            id: placeholderLabel
            objectName: "wmSearchPlaceholder"
            visible: pill.showPlaceholder
            anchors.verticalCenter: parent.verticalCenter
            x: pill.mirrored ? pill.inset : magnifier.x + magnifier.width + pill.iconGap
            width: Math.max(0, pill.width - 2 * pill.inset - magnifier.width - pill.iconGap)
            horizontalAlignment: Text.AlignLeft
            text: box.placeholder
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: Kirigami.Theme.defaultFont
            // WinUI TextFillColorSecondary: #C5FFFFFF / #9E000000.
            color: box.darkTheme ? Qt.rgba(1, 1, 1, 0xC5 / 255) : Qt.rgba(0, 0, 0, 0x9E / 255)
            Accessible.ignored: true
        }
    }
}
