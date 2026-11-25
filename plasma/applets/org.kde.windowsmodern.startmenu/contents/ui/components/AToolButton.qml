/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Flat/link-style button with icon and text, used for "All apps", "Back".
 *   Styling matches menu.11.next — rounded, subtle border, clean hover.
 ***************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme

Rectangle {
    id: item

    Win11Palette { id: fluent }

    property int buttonHeight: Math.floor(Kirigami.Units.gridUnit * 2)
    implicitHeight: buttonHeight
    implicitWidth: row.implicitWidth + (Kirigami.Units.mediumSpacing * 2)

    border.width: item.activeFocus || !linkStyle ? 1 : 0
    border.color: item.activeFocus ? fluent.accent : fluent.controlBorder
    radius: fluent.controlRadius
    color: mouseItem.containsPress ? fluent.controlPressed
        : mouseItem.containsMouse || item.activeFocus ? fluent.controlHover
        : linkStyle ? "transparent" : fluent.controlFill

    Behavior on color { ColorAnimation { duration: 90 } }

    smooth: true
    focus: true

    property alias text: lb.text
    property bool flat: false
    property bool linkStyle: false
    property alias iconName: icon.source
    property bool mirror: false

    signal clicked

    activeFocusOnTab: true
    Keys.onSpacePressed: item.clicked()
    Keys.onReturnPressed: item.clicked()
    Keys.onEnterPressed: item.clicked()

    // A button for screen readers too ("All apps", "Back"): it was exposed
    // as a plain label, which cannot be pressed.
    Accessible.role: Accessible.Button
    Accessible.name: lb.text
    Accessible.onPressAction: item.clicked()

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing / 2
        anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
        spacing: Kirigami.Units.smallSpacing
        LayoutMirroring.enabled: mirror

        Label {
            id: lb
            color: Kirigami.Theme.textColor
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
        }

        Kirigami.Icon {
            id: icon
            implicitHeight: Kirigami.Units.gridUnit
            implicitWidth: implicitHeight
            smooth: true
        }
    }

    MouseArea {
        id: mouseItem
        hoverEnabled: true
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
