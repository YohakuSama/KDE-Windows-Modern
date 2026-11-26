// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/lockMetrics.js" as LockMetrics
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/lockText.js" as LockText

TestCase {
    name: "SessionLockLayout"
    function test_referencePlacement() {
        compare(LockMetrics.avatarSize(480, 800), 160);
        compare(LockMetrics.formTop(800, 240), 172);
        compare(LockMetrics.formTop(400, 270), 66);
        compare(LockMetrics.passwordWidth, 296);
        compare(LockMetrics.passwordHeight, 30);
    }
    function test_localLanguageFallback() {
        compare(LockText.tr("Password", "Password", "zh-CN", "en_US"), "密码");
        compare(LockText.tr("Password", "Password", "", "zh_CN"), "密码");
        compare(LockText.tr("Password", "Password", "en-US", "zh_CN"), "Password");
        compare(LockText.tr("Password", "Kennwort", "de-DE", "de_DE"), "Kennwort");
    }
}
