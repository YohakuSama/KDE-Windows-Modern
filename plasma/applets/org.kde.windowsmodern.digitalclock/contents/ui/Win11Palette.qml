/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "code/colorType.js" as ColorType

// Windows 11 color tokens from docs/STYLE.md, resolved against the active
// Kirigami theme so both the dark and light global variants are supported.
QtObject {
    readonly property bool isDark: ColorType.isDark(Kirigami.Theme.backgroundColor)

    readonly property color background:       isDark ? "#202020" : "#F9F9F9"
    readonly property color surface:          isDark ? "#2C2C2C" : "#FFFFFF"
    readonly property color surfaceBorder:    ColorType.cardBorder(isDark)
    // Keep the solid fallback until the split window has a compositor blur region.
    readonly property color detachedPanel: ColorType.cardFill(isDark, false)
    readonly property color panelTint: isDark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color progressTrack: ColorType.trackFill(isDark)
    readonly property color panelBorder: ColorType.divider(isDark)
    readonly property color cardTint: isDark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.70)
    readonly property color text:             isDark ? "#FFFFFF" : "#1E1E1E"
    readonly property color textSecondary:    isDark ? "#9C9C9C" : "#5A5A5A"
    readonly property color textDisabled:     isDark ? "#5A5A5A" : "#A0A0A0"
    // The desktop theme inherits the live global scheme, including KDE's
    // wallpaper-derived and user-selected accents. Choose a readable ink.
    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor, detachedPanel, 3)
    readonly property color accentText: ColorType.contrastingForeground(accent)
    readonly property color accentLink: ColorType.accentForSurface(Kirigami.Theme.highlightColor, detachedPanel, 4.5)
    readonly property color hover:            isDark ? "#3F3F3F" : "#E9E9E9"
    readonly property color pressed:          isDark ? "#4A4A4A" : "#DADADA"
}
