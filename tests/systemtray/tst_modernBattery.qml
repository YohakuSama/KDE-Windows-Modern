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
        function test_stableGeometryAndExactFill() {
            const body = findChild(glyph, "wmBatteryOutline");
            const level = findChild(glyph, "wmBatteryLevelFill");
            verify(body !== null && level !== null);
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
            compare(glyph.fillFraction, 0.95);
            verify(level.width < body.width - 2 * level.inset);
            glyph.charging = true;
            compare(glyph.visualState, "charging");
            compare(glyph.fillColor, Qt.rgba(98/255, 184/255, 90/255, 1));
            glyph.charging = false;
            glyph.saver = true;
            glyph.percent = 20;
            compare(glyph.visualState, "saver");
            compare(glyph.fillFraction, 0.2);
            glyph.percent = 5;
            compare(glyph.visualState, "critical");
            glyph.percent = -1;
            compare(glyph.visualState, "unknown");
            verify(!level.visible);
            compare(glyph.implicitWidth, 25);
        }
    }
}
