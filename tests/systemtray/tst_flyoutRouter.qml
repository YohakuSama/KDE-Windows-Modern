// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui" as Tray

Item {
    Tray.FlyoutRouter { id: router }
    QtObject {
        id: deviceNotifier
        property QtObject plasmoid: QtObject {
            property string pluginName: "org.kde.plasma.devicenotifier"
        }
    }
    QtObject {
        id: unknownApplet
        property QtObject plasmoid: QtObject {
            property string pluginName: "org.example.unknown"
        }
    }
    TestCase {
        name: "NativeDeviceFlyoutRoute"
        function test_deviceNotifierUsesThemedPage() {
            compare(router.flyoutNameForApplet(deviceNotifier), "devices");
            verify(router.isThemedApplet(deviceNotifier));
            compare(router.flyoutNameForApplet(unknownApplet), "");
            verify(!router.isThemedApplet(unknownApplet));
            compare(router.flyoutNameForApplet(null), "");
        }
    }
}
