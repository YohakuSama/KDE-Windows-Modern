// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen" as Lock
import "../../plasma/look-and-feel/org.kde.windowsmodern.dark/contents/lockscreen" as Login
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/SignInMetrics.js" as Metrics

Item {
    width: 480
    height: 600
    Lock.SignInAvatar {
        id: avatar
        width: 192
        height: width
        source: ""
    }
    Login.SignInWelcome {
        id: welcome
        anchors.fill: parent
        accountName: "GeekerZ"
        message: "Welcome"
        visible: true
    }
    TestCase {
        name: "SignInGeometry"
        when: windowShown
        function test_defaultAvatar() {
            const circle = findChild(avatar, "wmAvatarCircle");
            const glyph = findChild(avatar, "wmAvatarGlyph");
            verify(circle.visible);
            tryCompare(glyph, "status", Image.Ready);
            compare(circle.radius, avatar.width / 2);
            fuzzyCompare(glyph.x + glyph.width / 2, avatar.width / 2, 0.5);
            fuzzyCompare(glyph.y + glyph.height / 2, avatar.height / 2, 0.5);
        }
        function test_welcomeCenterline() {
            const form = findChild(welcome, "wmWelcomeForm");
            tryVerify(() => form.height > 0);
            for (const name of ["wmWelcomeAvatar", "wmWelcomeName", "wmWelcomeRing", "wmWelcomeText"]) {
                const item = findChild(welcome, name);
                verify(item !== null);
                const center = item.mapToItem(welcome, item.width / 2, item.height / 2);
                fuzzyCompare(center.x, welcome.width / 2, 0.5);
            }
            compare(welcome.avatarSize, 192);
            compare(form.y, Metrics.formTop(welcome.height, form.height, welcome.avatarSize));
            verify(Metrics.avatarSize(280, 260) < 192);
        }
    }
}
