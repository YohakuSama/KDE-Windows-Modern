// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

Item {
    id: host
    width: 420
    height: 220
    property int brightness: 35
    property int volume: 60
    property int detailsCalls: 0
    Lib.Slider {
        id: brightnessRow
        width: 340
        height: implicitHeight
        iconSource: "brightness-high-symbolic"
        sliderAccessibleName: "Brightness"
        detailsAccessibleName: "Display settings"
        showArrow: true
        value: host.brightness
        onMoved: value => host.brightness = value
        onArrowClicked: host.detailsCalls++
    }
    Lib.Slider {
        id: volumeRow
        y: 44
        width: brightnessRow.width
        height: brightnessRow.height
        iconSource: "audio-volume-high-symbolic"
        sliderAccessibleName: "Volume"
        detailsAccessibleName: "Sound output"
        detailsIconSource: "multimedia-volume-control"
        showArrow: true
        value: host.volume
        onMoved: value => host.volume = value
    }
    Lib.FluentSlider {
        id: detail
        y: 100
        width: 200
        from: 0
        to: 100
        value: 40
        stepSize: 1
        Accessible.name: "Per-display brightness"
    }
    SignalSpy { id: releaseSpy; target: brightnessRow; signalName: "released" }
    TestCase {
        name: "QuickSettingsSliderInput"
        when: windowShown
        function control(row) { return findChild(row, "wmQuickSettingSlider"); }
        function init() {
            host.brightness = 35;
            host.volume = 60;
            host.detailsCalls = 0;
            brightnessRow.enabled = true;
            detail.value = 40;
            releaseSpy.clear();
        }
        function test_visibleTrackHasMouseHitTarget() {
            const a = control(brightnessRow);
            const b = control(volumeRow);
            verify(a !== null && b !== null);
            tryVerify(() => a.height >= 24 && b.height >= 24);
            compare(a.width, b.width);
            compare(a.mapToItem(brightnessRow, 0, 0).x, b.mapToItem(volumeRow, 0, 0).x);
            mouseClick(a, a.width * 0.8, a.height / 2, Qt.LeftButton);
            tryVerify(() => host.brightness >= 75 && host.brightness <= 85);
            compare(releaseSpy.count, 1);
            mouseClick(b, b.width * 0.25, b.height / 2, Qt.LeftButton);
            tryVerify(() => host.volume >= 20 && host.volume <= 30);
            compare(host.detailsCalls, 0);
        }
        function test_dragUpdatesBeforeRelease() {
            const a = control(brightnessRow);
            const start = a.handle.x + a.handle.width / 2;
            mousePress(a, start, a.height / 2, Qt.LeftButton);
            tryCompare(brightnessRow, "pressed", true);
            mouseMove(a, a.width * 0.9, a.height / 2, 20, Qt.LeftButton);
            tryVerify(() => host.brightness >= 85);
            compare(releaseSpy.count, 0);
            mouseRelease(a, a.width * 0.9, a.height / 2, Qt.LeftButton);
            tryCompare(brightnessRow, "pressed", false);
            compare(releaseSpy.count, 1);
            const b = control(volumeRow);
            mouseDrag(b, b.handle.x + b.handle.width / 2, b.height / 2,
                -b.width * 0.4, 0, Qt.LeftButton);
            tryVerify(() => host.volume <= 25);
        }
        function test_wheelAndKeyboard() {
            const a = control(brightnessRow);
            mouseWheel(a, a.width / 2, a.height / 2, 0, 120);
            tryCompare(host, "brightness", 36);
            a.forceActiveFocus();
            keyClick(Qt.Key_Right);
            tryCompare(host, "brightness", 37);
        }
        function test_disabledAndBackendUpdates() {
            const a = control(brightnessRow);
            brightnessRow.enabled = false;
            mouseClick(a, a.width * 0.9, a.height / 2, Qt.LeftButton);
            compare(host.brightness, 35);
            brightnessRow.enabled = true;
            host.brightness = 72;
            tryCompare(a, "value", 72);
            compare(releaseSpy.count, 0);
        }
        function test_detailSlider() {
            mouseClick(detail, detail.width * 0.8, detail.height / 2, Qt.LeftButton);
            tryVerify(() => detail.value >= 75 && detail.value <= 85);
            const before = detail.value;
            mouseWheel(detail, detail.width / 2, detail.height / 2, 0, 120);
            tryCompare(detail, "value", before + 1);
        }
    }
}
