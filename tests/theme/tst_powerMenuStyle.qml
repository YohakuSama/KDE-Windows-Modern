// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen" as Lock
import "../../plasma/look-and-feel/org.kde.windowsmodern.dark/contents/lockscreen" as Login

Item {
    width: 240
    height: 200
    Lock.FluentPowerMenuItem {
        id: lockItem
        width: 160
        text: "Sleep"
    }
    Login.FluentPowerMenuItem {
        id: loginItem
        y: 48
        width: 160
        text: "Sleep"
    }
    TestCase {
        name: "PowerMenuStyle"
        when: windowShown
        function test_sharedGeometry() {
            compare(lockItem.background.radius, 4);
            compare(loginItem.background.radius, 4);
            compare(lockItem.implicitHeight, loginItem.implicitHeight);
            verify(lockItem.implicitHeight >= 32);
            lockItem.actionAvailable = false;
            compare(lockItem.height, 0);
            lockItem.actionAvailable = true;
            verify(lockItem.height >= 32);
        }
    }
}
