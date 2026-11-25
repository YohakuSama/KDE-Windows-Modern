// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest

Item {
    id: fixture
    width: 640
    height: 400
    TestCase {
        name: "WindowsSessionSplash"
        when: windowShown
        function test_ringCenteredAndAnimated_data() {
            return [{tag:"dark", mode:"dark"}, {tag:"light", mode:"light"}];
        }
        function test_ringCenteredAndAnimated(data) {
            const path = "../../plasma/look-and-feel/org.kde.windowsmodern." + data.mode + "/contents/splash/Splash.qml";
            const component = Qt.createComponent(path);
            tryVerify(() => component.status !== Component.Loading);
            verify(component.status === Component.Ready, component.errorString());
            const splash = component.createObject(fixture, {width: fixture.width, height: fixture.height});
            verify(splash !== null);
            const ring = findChild(splash, "wmSessionLoadingRing");
            verify(ring !== null);
            tryCompare(ring, "width", 36);
            compare(ring.x + ring.width/2, splash.width/2);
            compare(ring.y + ring.height/2, splash.height/2);
            compare(ring.dotCount, 5);
            for (let i = 0; i < 5; ++i)
                verify(findChild(ring, "wmLoadingDot" + i) !== null);
            tryVerify(() => ring.phase > 0);
            splash.stage = 5;
            compare(splash.stage, 5);
            splash.destroy();
        }
    }
}
