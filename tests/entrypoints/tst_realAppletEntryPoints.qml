// SPDX-License-Identifier: GPL-3.0-or-later
// No mock import tree: load with the distro's actual Qt and Plasma modules.
// Component.Ready checks type resolution without requiring a live containment.
import QtQuick
import QtTest

TestCase {
    name: "RealAppletEntryPoints"
    function test_load_data() {
        return [
            {tag: "tray", name: "systemtray"},
            {tag: "clock", name: "digitalclock"},
            {tag: "start", name: "startmenu"}
        ];
    }
    function test_load(data) {
        const url = Qt.resolvedUrl("../../plasma/applets/org.kde.windowsmodern." + data.name + "/contents/ui/main.qml");
        const component = Qt.createComponent(url);
        tryVerify(() => component.status !== Component.Loading, 15000);
        verify(component.status === Component.Ready, component.errorString());
    }
}
