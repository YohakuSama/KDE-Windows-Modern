/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// Windows 11 color tokens from docs/STYLE.md, resolved against the active
// Kirigami theme so both the dark and light global variants are supported.
QtObject {
    readonly property bool isDark: {
        const bg = Kirigami.Theme.backgroundColor;
        return (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114) < 0.5;
    }

    readonly property color background:       isDark ? "#202020" : "#F9F9F9"
    readonly property color surface:          isDark ? "#2C2C2C" : "#FFFFFF"
    readonly property color surfaceBorder:    isDark ? "#3F3F3F" : "#E5E5E5"
    // Translucent internal surfaces keep the native popup material visible.
    readonly property color detachedPanel: isDark ? "#202020" : "#F2F2F2"
    readonly property color panelTint: isDark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color panelBorder: isDark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color cardTint: isDark ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, 0.70)
    readonly property color text:             isDark ? "#FFFFFF" : "#1E1E1E"
    readonly property color textSecondary:    isDark ? "#9C9C9C" : "#5A5A5A"
    readonly property color textDisabled:     isDark ? "#5A5A5A" : "#A0A0A0"
    // The desktop theme inherits the live global scheme, including KDE's
    // wallpaper-derived and user-selected accents. Choose a readable ink.
    function luminance(color) {
        const rgb = [color.r, color.g, color.b].map(value =>
            value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4));
        return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
    }
    function contrast(a, b) {
        const x = luminance(a);
        const y = luminance(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accentText: luminance(accent) <= 0.179 ? "#FFFFFF" : "#000000"
    readonly property color accentLink: contrast(accent, detachedPanel) >= 4.5 ? accent : text
    readonly property color hover:            isDark ? "#3F3F3F" : "#E9E9E9"
    readonly property color pressed:          isDark ? "#4A4A4A" : "#DADADA"
}
