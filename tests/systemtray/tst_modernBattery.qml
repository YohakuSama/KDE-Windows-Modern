// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/funcs.js" as Funcs

Item {
    width: 100
    height: 60
    Components.BatteryGlyph {
        id: glyph
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        foreground: "white"
        backgroundColor: "#202020"
    }
    TestCase {
        name: "ModernBatteryGlyph"
        when: windowShown
        function test_liveStateAndSize() {
            compare(glyph.implicitWidth, 20);
            compare(glyph.implicitHeight, 16);
            glyph.percent = 95;
            glyph.charging = true;
            compare(glyph.visualState, "charging");
            fuzzyCompare(glyph.fillFraction, 0.95, 0.0001);
            compare(glyph.levelColor, Qt.rgba(115/255, 216/255, 139/255, 1));
            const fill = findChild(glyph, "wmBatteryLevelFill");
            verify(fill !== null);
            fuzzyCompare(fill.width, 13 * 0.95, 0.001);
            glyph.charging = false;
            glyph.saver = true;
            glyph.percent = 20;
            compare(glyph.visualState, "saver");
            glyph.percent = 5;
            compare(glyph.visualState, "critical");
            glyph.percent = 75;
            glyph.saver = false;
            compare(glyph.visualState, "normal");
            glyph.percent = -1;
            compare(glyph.visualState, "unknown");
            compare(fill.visible, false);
        }
        function test_fillRange() {
            compare(Funcs.batteryFillFraction(-1), 0);
            compare(Funcs.batteryFillFraction(100), 1);
            compare(Funcs.batteryFillFraction(120), 1);
            compare(Funcs.batteryFillFraction(NaN), 0);
            compare(Funcs.batteryVisualState(95, true, false), "charging");
            compare(Funcs.batteryVisualState(20, false, false), "normal");
            compare(Funcs.batteryVisualState(20, false, true), "saver");
        }
        function test_lightPalette() {
            glyph.backgroundColor = "white";
            glyph.percent = 95;
            glyph.charging = true;
            compare(glyph.dark, false);
            compare(glyph.levelColor, Qt.rgba(33/255, 135/255, 57/255, 1));
            glyph.backgroundColor = "#202020";
        }
    }
}
