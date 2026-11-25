/* SPDX-License-Identifier: GPL-3.0-or-later */
// KSplash owns session startup; never delay a ready desktop.
import QtQuick
Rectangle {
    id: root
    color: "#000000"
    property int stage: 0
    SignInProgress {
        objectName: "wmSessionLoadingRing"
        anchors.centerIn: parent
        width: 36
        height: 36
        running: root.visible
    }
}
