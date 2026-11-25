// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen" as Lock
import "../../plasma/look-and-feel/org.kde.windowsmodern.dark/contents/lockscreen" as Login

Item {
    width: 320
    height: 240
    Lock.AccountAvatar { id: lockAvatar; width: size; height: size; size: 140 }
    Login.WinAvatar { id: loginAvatar; x: 160; width: size; height: size; size: 140 }
    TestCase {
        name: "DefaultAccountPortrait"
        when: windowShown
        function test_defaultAndCompact() {
            const large = findChild(lockAvatar, "wmDefaultAccountPortrait");
            const other = findChild(loginAvatar, "wmDefaultAccountPortrait");
            const glyph = findChild(large, "wmDefaultAccountGlyph");
            verify(large.visible);
            verify(other.visible);
            compare(large.color, Qt.color("#10FFFFFF"));
            compare(other.color, large.color);
            compare(glyph.width, 92);
            tryCompare(glyph, "status", Image.Ready);
            lockAvatar.size = 32;
            tryCompare(large, "compact", true);
            compare(large.color, Qt.color("#F2F2F2"));
            compare(glyph.width, 26);
            tryCompare(glyph, "status", Image.Ready);
            lockAvatar.size = 140;
        }
    }
}
