// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Components

Item {
    width: 400
    height: 200
    Components.PowerOption {
        id: row
        width: 180
        iconSource: "system-shutdown-symbolic"
        label: "Shut down"
    }
    TestCase {
        name: "StartActionMenuGeometry"
        when: windowShown
        function test_menuIconAndRowHaveIndependentSizes() {
            const glyph = findChild(row, "wmStartMenuActionGlyph");
            verify(glyph !== null);
            compare(row.height, 32);
            tryCompare(glyph, "width", 16);
            tryCompare(glyph, "height", 16);
            verify(!glyph.roundToIconSize);
            verify(row.implicitWidth > glyph.width + 20);
            row.width = 240;
            tryCompare(glyph, "width", 16);
            row.label = "账户设置";
            tryCompare(glyph, "height", 16);
        }
    }
}
