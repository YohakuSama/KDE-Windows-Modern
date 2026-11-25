// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/colorType.js" as ColorType

TestCase {
    name: "QuickSettingsAccentContrast"

    function test_foreground_data() {
        return [
            { tag: "dark theme accent", accent: "#4CC2FF", expected: "#000000" },
            { tag: "light theme accent", accent: "#0067C0", expected: "#FFFFFF" },
            { tag: "black", accent: "#000000", expected: "#FFFFFF" },
            { tag: "white", accent: "#FFFFFF", expected: "#000000" },
            { tag: "yellow", accent: "#FFFF00", expected: "#000000" },
            { tag: "navy", accent: "#000080", expected: "#FFFFFF" }
        ]
    }

    function test_foreground(data) {
        const color = Qt.color(data.accent);
        compare(ColorType.contrastingForeground(color), data.expected);
        verify(ColorType.contrastRatio(color, Qt.color(data.expected)) >= 4.5);
    }
}
