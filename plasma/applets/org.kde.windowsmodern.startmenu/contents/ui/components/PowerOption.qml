/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Single row inside the power-options popup: icon + label, hover
 *   highlight, click to activate.
 ***************************************************************************/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme

Item {
    id: option

    property string iconSource
    property string label
    property bool optionEnabled: true

    signal activated
    signal navigationRequested(int direction)

    enabled: optionEnabled
    activeFocusOnTab: optionEnabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if (optionEnabled) activated()
    Keys.onReturnPressed: if (optionEnabled) activated()
    Keys.onEnterPressed: if (optionEnabled) activated()
    Keys.onSpacePressed: if (optionEnabled) activated()
    Keys.onUpPressed: navigationRequested(-1)
    Keys.onDownPressed: navigationRequested(1)
    Keys.onBacktabPressed: navigationRequested(-1)
    Keys.onTabPressed: event => navigationRequested(event.modifiers & Qt.ShiftModifier ? -1 : 1)

    width: parent ? parent.width : Kirigami.Units.gridUnit * 10
    height: 36

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 5
        color: Kirigami.Theme.textColor
        opacity: !option.optionEnabled ? 0
            : hoverArea.containsPress ? 0.11
            : hoverArea.containsMouse || option.activeFocus ? 0.065 : 0
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    RowLayout {
        id: powerRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        spacing: 10

        Kirigami.Icon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            roundToIconSize: false
            source: option.iconSource
            fallback: option.iconSource.replace(/-symbolic$/, "")
            isMask: true
            color: Kirigami.Theme.textColor
            opacity: option.optionEnabled ? Theme.opacityFull : Theme.disabledIconOpacity
        }

        PlasmaComponents3.Label {
            text: option.label
            color: option.optionEnabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: option.optionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: option.optionEnabled
        onClicked: option.activated()
    }
}
