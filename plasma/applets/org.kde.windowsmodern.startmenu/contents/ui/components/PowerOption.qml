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
    property bool monochrome: true
    readonly property int glyphSize: Theme.menuGlyphSize

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

    implicitWidth: labelMetrics.advanceWidth + 2 * Theme.menuTextInset + glyphSize + Theme.menuIconGap
    TextMetrics {
        id: labelMetrics
        font: optionLabel.font
        text: option.label
    }
    implicitHeight: Theme.menuRowHeight
    width: parent ? parent.width : implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.menuRowRadius
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, hoverArea.containsPress ? 0.12 : Theme.menuHoverOpacity)
        opacity: option.optionEnabled && (hoverArea.containsMouse || option.activeFocus) ? Theme.opacityFull : Theme.opacityHidden
        Behavior on opacity { NumberAnimation { duration: 80 } }
    }

    RowLayout {
        id: powerRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.menuTextInset
        anchors.rightMargin: Theme.menuTextInset
        spacing: Theme.menuIconGap

        Kirigami.Icon {
            objectName: "wmStartMenuActionGlyph"
            Layout.minimumWidth: option.glyphSize
            Layout.preferredWidth: option.glyphSize
            Layout.maximumWidth: option.glyphSize
            Layout.minimumHeight: option.glyphSize
            Layout.preferredHeight: option.glyphSize
            Layout.maximumHeight: option.glyphSize
            roundToIconSize: false
            source: option.iconSource
            fallback: option.iconSource.replace(/-symbolic$/, "")
            isMask: option.monochrome
            color: option.monochrome ? Kirigami.Theme.textColor : "transparent"
            opacity: option.optionEnabled ? Theme.opacityFull : Theme.disabledIconOpacity
        }

        PlasmaComponents3.Label {
            id: optionLabel
            objectName: "wmStartMenuActionLabel"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: option.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: option.optionEnabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: Theme.menuFontSize
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
