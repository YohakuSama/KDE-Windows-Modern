// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick
import QtTest
import "../../plasma/look-and-feel/org.kde.windowsmodern.dark/contents/lockscreen" as Login

Item {
    width: 480
    height: 600
    Login.SignInWelcome {
        id: welcome
        width: 380
        height: 400
        accountName: "Long account name that must stay within the login form"
        message: "Welcome"
    }
    TestCase {
        name: "SignInWelcome"
        when: windowShown
        function test_boundedForm_data() {
            return [
                {tag: "normal", w: 380, h: 400},
                {tag: "short", w: 240, h: 220}
            ];
        }
        function test_boundedForm(data) {
            welcome.width = data.w;
            welcome.height = data.h;
            const form = findChild(welcome, "wmWelcomeForm");
            const avatar = findChild(welcome, "wmWelcomeAvatar");
            const name = findChild(welcome, "wmWelcomeName");
            const ring = findChild(welcome, "wmWelcomeRing");
            verify(form && avatar && name && ring);
            tryVerify(() => form.height > 0 && form.height <= welcome.height);
            verify(form.width <= welcome.width);
            verify(avatar.size <= welcome.height * 0.25);
            compare(name.text, welcome.accountName);
            verify(name.width <= form.width);
            verify(ring.running);
            welcome.visible = false;
            tryCompare(ring, "running", false);
            welcome.visible = true;
        }
    }
}
