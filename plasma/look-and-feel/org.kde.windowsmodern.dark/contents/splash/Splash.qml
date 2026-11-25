/* SPDX-License-Identifier: GPL-3.0-or-later */
import QtQuick

Rectangle {
    id: root
    color: "#101010"
    property int stage: 0

    SignInProgress {
        anchors.centerIn: parent
        width: 36
        height: width
        running: root.visible
    }
}
