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
import "../code/controlMetrics.js" as ControlMetrics

Rectangle {
    id: item

    property int buttonHeight: Math.floor(Kirigami.Units.gridUnit * 2)
    implicitHeight: buttonHeight
    implicitWidth: row.implicitWidth + (Kirigami.Units.mediumSpacing * 2)

    border.width: linkStyle ? 0 : 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, Theme.buttonBorderOpacity)

    radius: ControlMetrics.controlCornerRadius
    opacity: item.enabled ? 1.0 : 0.4
    color: {
        var hover = Qt.rgba(Kirigami.Theme.textColor.r,
                            Kirigami.Theme.textColor.g,
                            Kirigami.Theme.textColor.b, Theme.buttonHoverOpacity);
        var pressedFill = Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.12);
        if (flat) {
            return mouseItem.containsPress ? pressedFill
                   : (mouseItem.containsMouse || item.activeFocus)
                   ? Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, Theme.buttonFlatHoverOpacity)
                   : linkStyle ? "transparent" : Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, Theme.buttonFlatBackgroundOpacity);
        }
        return mouseItem.containsPress ? pressedFill
               : (mouseItem.containsMouse || item.activeFocus) ? hover : Kirigami.Theme.backgroundColor;
    }

    Behavior on color { ColorAnimation { duration: ControlMetrics.microInteractionDuration } }

    smooth: true
    focus: true

    property alias text: lb.text
    property bool flat: false
    property bool linkStyle: false
    property string iconName: ""
    property bool mirror: false
    readonly property bool rtl: item.LayoutMirroring.enabled

    function directionalRole(role, mirrored) {
        if (!mirrored) return role;
        if (role === "go-next-symbolic") return "go-previous-symbolic";
        if (role === "go-previous-symbolic") return "go-next-symbolic";
        if (role === "go-next") return "go-previous";
        if (role === "go-previous") return "go-next";
        return role;
    }

    signal clicked

    activeFocusOnTab: item.enabled
    Keys.onSpacePressed: if (item.enabled) item.clicked()
    Keys.onReturnPressed: if (item.enabled) item.clicked()
    Keys.onEnterPressed: if (item.enabled) item.clicked()

    // A button for screen readers too ("All apps", "Back"): it was exposed
    // as a plain label, which cannot be pressed.
    Accessible.role: Accessible.Button
    Accessible.name: lb.text
    Accessible.onPressAction: if (item.enabled) item.clicked()

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing / 2
        anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
        spacing: Kirigami.Units.smallSpacing
        layoutDirection: (item.rtl !== item.mirror) ? Qt.RightToLeft : Qt.LeftToRight

        Label {
            id: lb
            color: Kirigami.Theme.textColor
            textFormat: Text.PlainText
            elide: Text.ElideRight
            Layout.leftMargin: (item.rtl !== item.mirror) ? 0 : Kirigami.Units.smallSpacing
            Layout.rightMargin: (item.rtl !== item.mirror) ? Kirigami.Units.smallSpacing : 0
            Layout.fillWidth: true
        }

        NativeGlyph {
            id: icon
            roleName: item.directionalRole(item.iconName, item.rtl)
            implicitHeight: 12
            implicitWidth: 12
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
        }
    }

    MouseArea {
        id: mouseItem
        enabled: item.enabled
        hoverEnabled: true
        anchors.fill: parent
        cursorShape: item.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: item.clicked()
    }
}
