/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami

// Small Windows-11-style triangular button used for month navigation.
MouseArea {
    id: root

    property bool up: true

    property color glyphColor: "#FFFFFF"
    property color hoverColor: "#3F3F3F"
    property color pressedColor: "#4A4A4A"

    implicitWidth: 28
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.onPressAction: root.clicked(null)
    Keys.onReturnPressed: root.clicked(null)
    Keys.onEnterPressed: root.clicked(null)
    Keys.onSpacePressed: root.clicked(null)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

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
        width: 8
        height: 6

        Connections {
            target: root
            function onGlyphColorChanged() { glyph.requestPaint(); }
            function onUpChanged() { glyph.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = root.glyphColor;
            ctx.beginPath();
            ctx.moveTo(0, root.up ? 5 : 1);
            ctx.lineTo(4, root.up ? 0 : 6);
            ctx.lineTo(8, root.up ? 5 : 1);
            ctx.closePath();
            ctx.fill();
        }
    }
}
