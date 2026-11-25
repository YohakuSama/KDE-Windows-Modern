// SPDX-License-Identifier: LGPL-2.0-or-later
import QtQuick

// Continuous indeterminate arc, not the legacy dotted Windows ring.
// An independent rotation and a changing sweep reproduce the form of
// a progressive ring without borrowing proprietary animation assets.
Item {
    id: control
    property bool running: visible
    property color color: "#FFFFFF"
    property real sweep: 1.25
    implicitWidth: 36
    implicitHeight: 36

    Canvas {
        id: arc
        objectName: "wmProgressArc"
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const thickness = Math.max(2, Math.min(width, height) * 0.105);
            const radius = Math.max(0, Math.min(width, height) / 2 - thickness / 2 - 1);
            if (radius <= 0)
                return;
            ctx.strokeStyle = control.color;
            ctx.lineWidth = thickness;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, radius, -Math.PI / 2, -Math.PI / 2 + control.sweep, false);
            ctx.stroke();
        }
        Connections {
            target: control
            function onSweepChanged() { arc.requestPaint(); }
            function onColorChanged() { arc.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1300
            loops: Animation.Infinite
            running: control.running && control.visible
        }
    }
    SequentialAnimation on sweep {
        running: control.running && control.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1.25; to: 4.5; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { from: 4.5; to: 1.25; duration: 650; easing.type: Easing.InOutSine }
    }
}
