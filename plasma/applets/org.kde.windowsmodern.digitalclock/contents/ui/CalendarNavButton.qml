/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami

// Compact stroke chevron; retain the 28px target and actual calendar action.
MouseArea {
    id: root

    property bool up: true
    signal activated()

    property color glyphColor: "#FFFFFF"
    property color hoverColor: "#3F3F3F"
    property color pressedColor: "#4A4A4A"

    implicitWidth: 28
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.activated()
    onClicked: root.activated()
    Keys.onReturnPressed: root.activated()
    Keys.onSpacePressed: root.activated()

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.containsPress ? root.pressedColor
                                  : (root.containsMouse || root.activeFocus ? root.hoverColor : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    Canvas {
        id: glyph
        anchors.centerIn: parent
        width: 12
        height: 8

        Connections {
            target: root
            function onGlyphColorChanged() { glyph.requestPaint(); }
            function onUpChanged() { glyph.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = root.glyphColor;
            ctx.lineWidth = 1.4;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(2, root.up ? 6 : 2);
            ctx.lineTo(6, root.up ? 2 : 6);
            ctx.lineTo(10, root.up ? 6 : 2);
            ctx.stroke();
        }
    }
}
