// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/funcs.js" as Funcs
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

Item {
    width: 360
    height: 100
    Lib.Slider {
        id: brightness
        width: parent.width
        height: 36
        reserveDetailsSpace: true
        iconSource: "brightness-high-symbolic"
        value: 35
        onMoved: v => value = v
    }
    Lib.Slider {
        id: volume
        y: 48
        width: parent.width
        height: 36
        reserveDetailsSpace: true
        showArrow: true
        soundOutputDetails: true
        iconSource: "audio-volume-high-symbolic"
        value: 35
        onMoved: v => value = v
    }
    TestCase {
        name: "InputMethodAndSlider"
        when: windowShown
        function test_languageLabels() {
            compare(Funcs.inputMethodLabel("Fcitx", "fcitx-rime", "中州韵"), "中");
            compare(Funcs.inputMethodLabel("Fcitx", "fcitx_rime_latin", "中州韵"), "英");
            compare(Funcs.inputMethodLabel("Fcitx", "fcitx_rime_latin_upper", "中州韵"), "英");
            compare(Funcs.inputMethodLabel("Fcitx", "fcitx-rime-latin-symbolic", "Rime"), "英");
            compare(Funcs.inputMethodLabel("Fcitx", "fcitx_rime_disable", "中州韵"), "");
            compare(Funcs.inputMethodLabel("Fcitx", "", "中州韻"), "");
            compare(Funcs.inputMethodLabel("Fcitx", "input-keyboard", "中州韵"), "");
            compare(Funcs.inputMethodLabel("Fcitx", "input-keyboard", "Keyboard - English (US)"), "英");
            compare(Funcs.inputMethodLabel("Fcitx", "input-keyboard", "Keyboard - Japanese"), "");
            compare(Funcs.inputMethodLabel("Other", "fcitx-rime", "中文"), "");
        }
        function test_equalTracks() {
            const a = findChild(brightness, "wmFluentSliderTrack");
            const b = findChild(volume, "wmFluentSliderTrack");
            verify(a !== null && b !== null);
            tryVerify(() => a.width > 0 && b.width > 0);
            compare(a.x, b.x);
            compare(a.width, b.width);
            compare(a.background.width, b.background.width);
            verify(a.background.width >= brightness.width * 0.66);
            verify(a.height >= 34 && b.height >= 34);
        }

        function test_realPointerAndWheel_data() {
            return [{tag: "brightness", row: brightness}, {tag: "volume", row: volume}];
        }

        function test_realPointerAndWheel(data) {
            const row = data.row;
            row.value = 35;
            const control = findChild(row, "wmFluentSliderTrack");
            tryCompare(control, "value", 35);
            const y = Math.round(control.height / 2);
            mousePress(control, Math.round(control.width * 0.35), y);
            tryCompare(control, "pressed", true);
            mouseMove(control, Math.round(control.width * 0.82), y, 80);
            tryVerify(() => row.value >= 75);
            // A late reply with the pre-drag backend value must not move
            // the live pointer-controlled thumb backwards.
            const draggedValue = control.value;
            row.value = 35;
            wait(30);
            compare(control.value, draggedValue);
            row.value = draggedValue;
            mouseRelease(control, Math.round(control.width * 0.82), y);
            tryCompare(control, "pressed", false);
            mouseClick(control, Math.round(control.width * 0.20), y);
            tryVerify(() => row.value <= 28);
            const before = row.value;
            mouseWheel(control, Math.round(control.width / 2), y, 0, 120);
            tryVerify(() => row.value > before);
        }
    }
}
