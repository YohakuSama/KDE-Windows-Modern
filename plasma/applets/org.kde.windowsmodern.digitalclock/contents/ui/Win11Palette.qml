/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// Windows 11 color tokens from docs/STYLE.md, resolved against the active
// Kirigami theme so both the dark and light global variants are supported.
QtObject {
    readonly property bool isDark: luminance(Kirigami.Theme.backgroundColor) <= 0.179

    readonly property color background:       isDark ? "#202020" : "#F9F9F9"
    readonly property color surface:          isDark ? "#2C2C2C" : "#FFFFFF"
    readonly property color surfaceBorder:    isDark ? "#383838" : "#DCDCDC"
    // Translucent internal surfaces keep the native popup material visible.
    readonly property color detachedPanel: isDark ? "#202020" : "#F2F2F2"
    readonly property color panelTint: isDark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color progressTrack: isDark ? "#929292" : "#767676"
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
    function accentForSurface(source, surface, minimum) {
        const opaque = Qt.rgba(source.r, source.g, source.b, 1);
        if (contrast(opaque, surface) >= minimum) return opaque;
        const target = luminance(surface) <= 0.179 ? 1 : 0;
        let low = 0, high = 1;
        for (let i = 0; i < 12; ++i) {
            const w = (low + high) / 2;
            const mixed = Qt.rgba(opaque.r + (target - opaque.r) * w,
                opaque.g + (target - opaque.g) * w, opaque.b + (target - opaque.b) * w, 1);
            if (contrast(mixed, surface) >= minimum) high = w;
            else low = w;
        }
        return Qt.rgba(opaque.r + (target - opaque.r) * high,
            opaque.g + (target - opaque.g) * high, opaque.b + (target - opaque.b) * high, 1);
    }
    readonly property color accent: accentForSurface(Kirigami.Theme.highlightColor, detachedPanel, 3)
    readonly property color accentText: luminance(accent) <= 0.179 ? "#FFFFFF" : "#000000"
    readonly property color accentLink: accentForSurface(Kirigami.Theme.highlightColor, detachedPanel, 4.5)
    readonly property color hover:            isDark ? "#3F3F3F" : "#E9E9E9"
    readonly property color pressed:          isDark ? "#4A4A4A" : "#DADADA"
}
