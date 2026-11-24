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
    }

    TestCase {
        name: "NativeBatteryGlyph"
        when: windowShown
        function test_nativeSourceAndStableGeometry() {
            const icon = findChild(glyph, "wmBatterySourceIcon");
            verify(icon !== null);
            verify(!icon.roundToIconSize);
            verify(findChild(glyph, "wmBatteryOutline") === null);
            verify(findChild(glyph, "wmBatteryLevelFill") === null);
            glyph.glyphSize = 20;
            compare(glyph.implicitWidth, 25);
            compare(glyph.implicitHeight, 20);
            compare(icon.width, 25);
            compare(icon.height, 25);
            glyph.percent = 95;
            glyph.charging = true;
            compare(glyph.iconName, "battery-100-charging-symbolic");
            glyph.charging = false;
            glyph.saver = true;
            glyph.percent = 20;
            compare(glyph.iconName, "battery-020-profile-powersave-symbolic");
            glyph.charging = true;
            compare(glyph.iconName, "battery-020-charging-symbolic");
            glyph.charging = false;
            glyph.saver = false;
            glyph.percent = 5;
            compare(glyph.iconName, "battery-000-symbolic");
            glyph.percent = -1;
            compare(glyph.iconName, "battery-unknown-symbolic");
            glyph.charging = true;
            compare(glyph.iconName, "battery-unknown-charging-symbolic");
            compare(icon.width, 25);
        }

        function test_originalSaverLevels() {
            for (let n = 0; n <= 100; n += 10) {
                compare(Funcs.batteryIconName(n, false, true),
                    "battery-" + String(n).padStart(3, "0") + "-profile-powersave-symbolic");
            }
            compare(Funcs.batteryIconName(NaN, false, true), "battery-unknown-symbolic");
        }
    }
}
