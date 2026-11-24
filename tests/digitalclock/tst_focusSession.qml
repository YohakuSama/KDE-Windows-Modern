// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui"

Item {
    QtObject {
        id: dnd
        property var notificationsInhibitedUntil
        property int saves: 0
        function save() { saves++; }
    }
    FocusSession { id: session; settings: dnd }

    TestCase {
        name: "FocusSession"
        function init() {
            session.stop();
            session.durationMinutes = 30;
            dnd.notificationsInhibitedUntil = undefined;
            dnd.saves = 0;
        }
        function cleanup() { session.stop(); }
        function test_durationBounds() {
            session.adjust(-100);
            compare(session.durationMinutes, 5);
            session.adjust(1000);
            compare(session.durationMinutes, 240);
        }
        function test_deadlineAndExpiry() {
            const now = Date.now();
            session.start(now);
            compare(session.remainingSeconds, 1800);
            compare(dnd.notificationsInhibitedUntil.getTime(), session.endTime);
            session.adjust(5);
            compare(session.durationMinutes, 30);
            session.tick(now + 123000);
            compare(session.countdown, "27:57");
            session.tick(now + 1800000);
            verify(!session.running);
            compare(dnd.notificationsInhibitedUntil, undefined);
        }
        function test_preserveManualDnd() {
            const now = Date.now();
            const manual = new Date(now + 86400000);
            dnd.notificationsInhibitedUntil = manual;
            session.start(now);
            session.stop();
            compare(dnd.notificationsInhibitedUntil.getTime(), manual.getTime());
            compare(dnd.saves, 0);
        }
        function test_preserveUserChangeDuringFocus() {
            const now = Date.now();
            session.start(now);
            const manual = new Date(now + 86400000);
            dnd.notificationsInhibitedUntil = manual;
            session.stop();
            compare(dnd.notificationsInhibitedUntil.getTime(), manual.getTime());
        }
    }
}
