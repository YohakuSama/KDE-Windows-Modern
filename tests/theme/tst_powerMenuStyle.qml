// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen" as Lock
import "../../plasma/look-and-feel/org.kde.windowsmodern.dark/contents/lockscreen" as Login

Item {
    width: 320
    height: 240
    QQC2.Menu {
        id: lockMenu
        width: 160
        Lock.FluentPowerMenuItem {
            id: lockItem
            width: lockMenu.availableWidth
            text: "Sleep"
            icon.name: "system-suspend"
        }
    }
    QQC2.Menu {
        id: loginMenu
        width: 160
        Login.FluentPowerMenuItem {
            id: loginItem
            width: loginMenu.availableWidth
            text: "Sleep"
            icon.name: "system-suspend"
        }
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
            verify(!lockItem.enabled);
            lockItem.actionAvailable = true;
            verify(lockItem.height >= 32);
            verify(lockItem.enabled);
        }
        function test_explicitMenuItemsUseSharedControls() {
            compare(lockMenu.itemAt(0), lockItem);
            compare(loginMenu.itemAt(0), loginItem);
            compare(lockItem.width, lockMenu.availableWidth);
            compare(loginItem.width, loginMenu.availableWidth);
        }
    }
}
