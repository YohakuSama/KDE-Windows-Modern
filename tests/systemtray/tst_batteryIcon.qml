// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/funcs.js" as Funcs

TestCase {
    name: "BatteryStatusIcon"

    function test_iconName_data() {
        const values = [
            [-1, "unknown"], [NaN, "unknown"], [Infinity, "unknown"],
            [0, "000"], [5, "000"], [6, "010"], [14, "010"], [15, "020"],
            [44, "040"], [45, "050"], [84, "080"], [85, "090"],
            [94, "090"], [95, "100"], [100, "100"], [101, "100"]
        ];
        const rows = [];
        for (let i = 0; i < values.length; ++i) {
            for (const pluggedIn of [false, true]) {
                rows.push({tag: String(i) + "-" + String(pluggedIn),
                    percent: values[i][0], pluggedIn: pluggedIn,
                    expected: "battery-" + values[i][1]
                        + (pluggedIn ? "-charging" : "") + "-symbolic"});
            }
        }
        return rows;
    }

    function test_boundedLevel() {
        for (const level of [-1, NaN, Infinity, -Infinity])
            compare(Funcs.boundedBatteryPercent(level), -1);
        compare(Funcs.boundedBatteryPercent(0), 0);
        compare(Funcs.boundedBatteryPercent(99.5), 99.5);
        compare(Funcs.boundedBatteryPercent(100), 100);
        compare(Funcs.boundedBatteryPercent(101), 100);
    }

    function test_iconName(data) {
        compare(Funcs.batteryIconName(data.percent, data.pluggedIn), data.expected);
    }
}
