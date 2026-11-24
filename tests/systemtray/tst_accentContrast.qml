// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/colorType.js" as ColorType

TestCase {
    name: "QuickSettingsAccentContrast"

    function test_foreground_data() {
        return [
            { tag: "dark theme accent", accent: "#4CC2FF", expected: "#1E1E1E" },
            { tag: "light theme accent", accent: "#0067C0", expected: "#FFFFFF" },
            { tag: "black", accent: "#000000", expected: "#FFFFFF" },
            { tag: "white", accent: "#FFFFFF", expected: "#1E1E1E" },
            { tag: "yellow", accent: "#FFFF00", expected: "#1E1E1E" },
            { tag: "navy", accent: "#000080", expected: "#FFFFFF" }
        ]
    }

    function test_foreground(data) {
        compare(ColorType.contrastingForeground(Qt.color(data.accent)), data.expected)
    }
}
