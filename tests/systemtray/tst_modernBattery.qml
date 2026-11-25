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
        function init() {
            glyph.percent = -1;
            glyph.charging = false;
            glyph.pluggedIn = false;
            glyph.saver = false;
        }
        function test_shellStateCodepoints() {
            glyph.percent = 80;
            compare(glyph.outlineCode, 0xf8d0);
            compare(glyph.fillCode, 0xf8d8);
            glyph.charging = true;
            compare(glyph.outlineCode, 0xf8db);
            compare(glyph.fillCode, 0xf8e1);
            glyph.pluggedIn = true;
            glyph.charging = false;
            compare(glyph.outlineCode, 0xf8e4);
            compare(glyph.fillCode, 0xf8ea);
            glyph.pluggedIn = false;
            glyph.saver = true;
            compare(glyph.outlineCode, 0xf849);
            compare(glyph.fillCode, 0xf84f);
            glyph.percent = 20;
            compare(glyph.fillCode, 0xf8d2);
            glyph.percent = 5;
            compare(glyph.fillCode, 0);
        }
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
