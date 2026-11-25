/* SPDX-License-Identifier: GPL-3.0-or-later */
// Session startup (after authentication), not a simulated boot timer.
// KSplash owns the lifecycle; the ring never delays a ready desktop.
import QtQuick

Rectangle {
    id: root
    color: "#101010"
    property int stage: 0

    Canvas {
        id: ring
        objectName: "wmSessionLoadingRing"
        anchors.centerIn: parent
        width: 36
        height: 36
        property real phase: 0
        onPhaseChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        NumberAnimation on phase {
            from: 0
            to: 1
            duration: 1600
            loops: Animation.Infinite
            running: ring.visible
        }

        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.clearRect(0, 0, width, height);
            // Growing/shrinking continuous arc with rounded endcaps.
            const wave = (1 - Math.cos(2 * Math.PI * phase)) / 2;
            const start = -Math.PI / 2 + 4 * Math.PI * phase;
            const sweep = Math.PI * (0.25 + 1.25 * wave);
            c.strokeStyle = "#FFFFFF";
            c.lineWidth = 2.5;
            c.lineCap = "round";
            c.beginPath();
            c.arc(width / 2, height / 2, Math.min(width, height) * 0.39,
                start, start + sweep, false);
            c.stroke();
        }
    }
}
