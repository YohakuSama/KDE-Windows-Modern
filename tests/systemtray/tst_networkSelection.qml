// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib

TestCase {
    name: "NetworkCardSelection"
    Lib.NetworkSelection { id: state }
    function init() { state.reset(); }
    function test_onlyOneCardAndExplicitCollapse() {
        state.offerConnected("device|network-a");
        compare(state.expandedKey, "device|network-a");
        state.offerConnected("device|network-b");
        compare(state.expandedKey, "device|network-a");
        state.toggle("device|network-b");
        compare(state.expandedKey, "device|network-b");
        state.toggle("device|network-b");
        compare(state.expandedKey, "");
        state.offerConnected("device|network-a");
        compare(state.expandedKey, "");
        state.reset();
        state.offerConnected("device|network-a");
        compare(state.expandedKey, "device|network-a");
    }
    function test_disappearingCardDoesNotReopen() {
        state.toggle("device|network-b");
        state.forget("device|network-a");
        compare(state.expandedKey, "device|network-b");
        state.forget("device|network-b");
        compare(state.expandedKey, "");
        state.offerConnected("device|network-a");
        compare(state.expandedKey, "");
    }
}
