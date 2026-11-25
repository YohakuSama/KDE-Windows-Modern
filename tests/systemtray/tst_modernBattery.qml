// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

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
        name: "ModernBatteryGlyph"
        when: windowShown
        function test_stableGeometryAndNativeStates() {
            verify(findChild(glyph, "wmBatteryNativeGlyph") !== null);
            glyph.glyphSize = 16;
            compare(glyph.implicitWidth, 20);
            compare(glyph.implicitHeight, 16);
            glyph.glyphSize = 20;
            compare(glyph.implicitWidth, 25);
            compare(glyph.implicitHeight, 20);
            glyph.charging = false;
            glyph.saver = false;
            glyph.percent = 95;
            compare(glyph.visualState, "normal");
            compare(glyph.iconName, "battery-100-symbolic");
            glyph.charging = true;
            compare(glyph.iconName, "battery-100-charging-symbolic");
            glyph.charging = false;
            glyph.saver = true;
            glyph.percent = 20;
            compare(glyph.iconName, "battery-020-profile-powersave-symbolic");
            glyph.saver = false;
            glyph.percent = 5;
            compare(glyph.iconName, "battery-000-symbolic");
            glyph.percent = -1;
            compare(glyph.iconName, "battery-unknown-symbolic");
            compare(glyph.implicitWidth, 25);
        }
    }
}
