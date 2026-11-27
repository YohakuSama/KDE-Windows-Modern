// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/lockMetrics.js" as LockMetrics
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/lockText.js" as LockText
import "../../plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen/controlMetrics.js" as ControlMetrics

TestCase {
    name: "SessionLockLayout"
    function test_referencePlacement() {
        compare(LockMetrics.avatarSize(480, 800), 160);
        compare(LockMetrics.formTop(800, 240), 172);
        compare(LockMetrics.formTop(400, 270), 66);
        compare(LockMetrics.passwordWidth, 296);
        compare(LockMetrics.passwordHeight, 30);
        compare(LockMetrics.loginButtonRadius, 6);
        compare(LockMetrics.clockLineSpacingFactor, 0.5);
        compare(LockMetrics.powerMenuPadding, 4);
        compare(LockMetrics.loginPowerMenuWidth, 150);
        compare(LockMetrics.lockScreenPowerMenuWidth, 160);
        compare(LockMetrics.menuRadius, ControlMetrics.overlayCornerRadius);
        compare(ControlMetrics.controlCornerRadius, 4);
        compare(ControlMetrics.menuItemMinimumHeight, 32);
    }
    function test_localLanguageFallback() {
        compare(LockText.tr("Password", "Password", "zh-CN", "en_US"), "密码");
        compare(LockText.tr("Password", "Password", "", "zh_CN"), "密码");
        compare(LockText.tr("Password", "Password", "en-US", "zh_CN"), "Password");
        compare(LockText.tr("Password", "Kennwort", "de-DE", "de_DE"), "Kennwort");
    }
}
