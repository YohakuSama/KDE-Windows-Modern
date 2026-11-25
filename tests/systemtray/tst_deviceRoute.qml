// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui" as Tray

TestCase {
    name: "NativeDeviceRoute"
    Tray.FlyoutRouter { id: router }
    function test_bluetoothAndNativeDevicePages() {
        compare(router.flyoutNameForApplet({plasmoid: {pluginName: "org.kde.plasma.bluetooth"}}), "bluetooth");
        verify(router.isThemedApplet({plasmoid: {pluginName: "org.kde.plasma.bluetooth"}}));
        compare(router.flyoutNameForApplet({plasmoid: {pluginName: "org.kde.plasma.devicenotifier"}}), "");
        compare(router.flyoutNameForApplet({plasmoid: {pluginName: "org.kde.plasma.devicenotifier"}, fullRepresentationItem: {}}), "");
        compare(router.flyoutNameForApplet({plasmoid: {pluginName: "org.kde.plasma.devicenotifier"}, fullRepresentationItem: {model: {}}}), "devices");
    }
    function test_themedPagesAndFallback() {
        compare(router.flyoutNameForApplet({plasmoid: {pluginName: "org.kde.plasma.brightness"}}), "brightness");
        compare(router.flyoutNameForApplet({Plasmoid: {pluginName: "org.kde.plasma.networkmanagement"}}), "network");
        compare(router.flyoutNameForApplet(null), "");
    }
}
