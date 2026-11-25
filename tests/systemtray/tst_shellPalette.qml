// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Tray
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Start
import "../../plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui" as Clock

TestCase {
    name: "SharedShellPalette"
    Tray.Win11Palette { id: trayPalette; themeBackground: "#202020" }
    Start.Win11Palette { id: startPalette; themeBackground: "#202020" }
    Clock.Win11Palette { id: clockPalette; themeBackground: "#202020" }

    function test_variants_data() {
        return [
            {tag: "dark", bg: "#202020", menu: "#2C2C2C", border: "#3F3F3F", dark: true},
            {tag: "light", bg: "#F9F9F9", menu: "#F9F9F9", border: "#E5E5E5", dark: false}
        ];
    }

    function test_variants(data) {
        for (const palette of [trayPalette, startPalette, clockPalette]) {
            palette.themeBackground = data.bg;
            compare(palette.isDark, data.dark);
            compare(palette.menuBackground, Qt.color(data.menu));
            compare(palette.menuBorder, Qt.color(data.border));
            compare(palette.menuRadius, 8);
            compare(palette.controlRadius, 4);
            compare(palette.menuIconSize, 16);
            compare(palette.controlHeight, 32);
        }
        compare(trayPalette.controlHover, startPalette.controlHover);
        compare(startPalette.controlHover, clockPalette.controlHover);
        compare(trayPalette.controlPressed, clockPalette.controlPressed);
    }
}
