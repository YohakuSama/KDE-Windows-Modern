// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Components
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/theme.js" as Theme

Item {
    id: root
    width: 640
    height: 500

    Components.ContextMenu {
        id: menu
        anchors.fill: parent
    }

    TestCase {
        name: "SharedStartMenuSurface"
        when: windowShown

        function test_sharedWidthAndAnchors() {
            const w = Theme.actionMenuWidth(100, 640);
            compare(w, 184);
            const a = Theme.actionMenuPosition(52, 440, 100, 40, w, 136, 640, 500, true);
            const p = Theme.actionMenuPosition(548, 440, 40, 40, w, 136, 640, 500, false);
            compare(a.x, 52);
            compare(p.x + w, 588);
            compare(a.y, p.y);
            compare(a.y + 136 + Theme.menuAnchorGap, 440);
            compare(Theme.actionMenuWidth(500, 150), 138);
        }

        function test_contextUsesSameSurfaceAndRows() {
            menu.open([
                {text: "账户设置", icon: "configure-symbolic", actionId: "settings"},
                {text: "锁定", icon: "system-lock-screen-symbolic", actionId: "lock"},
                {type: "separator"},
                {text: "退出登录", icon: "system-log-out-symbolic", actionId: "logout", enabled: false}
            ], 50, 300, {});
            tryCompare(menu, "opened", true);
            const surface = findChild(menu, "wmStartContextMenuSurface");
            verify(surface !== null);
            tryCompare(surface, "width", 184);
            tryCompare(surface, "height", 105);
            compare(surface.frameRadius, 8);
            compare(surface.contentInset, 4);
            menu.close();
            compare(menu.opened, false);
        }
    }
}
