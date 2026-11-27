// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

QtObject {
    // Exactly one card is expanded. An initial active connection may claim
    // it; model updates must not reopen a card the user explicitly closed.
    property string expandedKey: ""
    property bool userSelected: false

    function offerConnected(key) {
        if (!userSelected && expandedKey === "" && key)
            expandedKey = key;
    }
    function toggle(key) {
        if (!key) return;
        userSelected = true;
        expandedKey = expandedKey === key ? "" : key;
    }
    function forget(key) {
        if (key && expandedKey === key)
            expandedKey = "";
    }
    function reset() {
        expandedKey = "";
        userSelected = false;
    }
}
