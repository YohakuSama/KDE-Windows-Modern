// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui/code/notificationPresentation.js" as Policy

TestCase {
    name: "NotificationTaskbarVisibility"
    function test_state_data() {
        return [
            { tag: "empty", configured:true, horizontal:true, available:true, count:0, dnd:false, visible:false },
            { tag: "one", configured:true, horizontal:true, available:true, count:1, dnd:false, visible:true },
            { tag: "history", configured:true, horizontal:true, available:true, count:8, dnd:false, visible:true },
            { tag: "dndEmpty", configured:true, horizontal:true, available:true, count:0, dnd:true, visible:true },
            { tag: "dndHistory", configured:true, horizontal:true, available:true, count:3, dnd:true, visible:true },
            { tag: "disabled", configured:false, horizontal:true, available:true, count:5, dnd:true, visible:false },
            { tag: "vertical", configured:true, horizontal:false, available:true, count:5, dnd:true, visible:false },
            { tag: "unavailable", configured:true, horizontal:true, available:false, count:5, dnd:true, visible:false }
        ];
    }
    function test_state(row) {
        compare(Policy.showBell(row.configured, row.horizontal, row.available, row.count, row.dnd), row.visible);
    }
    function test_panelGlyph() {
        const dnd = "notifications-disabled-symbolic";
        const filled = "wm-notification-snooze-filled-symbolic";
        compare(Policy.panelBellIcon(dnd, true, false, true), filled);
        compare(Policy.panelBellIcon(dnd, true, true, true), dnd);
        compare(Policy.panelBellIcon(dnd, true, false, false), dnd);
        compare(Policy.panelBellIcon("notification-active-symbolic", false, false, true),
                "notification-active-symbolic");
    }
    function test_transition() {
        compare(Policy.showBell(true, true, true, 0, false), false);
        compare(Policy.showBell(true, true, true, 1, false), true);
        compare(Policy.showBell(true, true, true, 0, false), false);
        compare(Policy.showBell(true, true, true, 0, true), true);
        compare(Policy.showBell(true, true, true, 0, false), false);
    }
}
