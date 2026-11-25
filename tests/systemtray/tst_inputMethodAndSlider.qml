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
        }
    }
}
