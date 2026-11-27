/*
    SPDX-FileCopyrightText: 2014 Ashish Madeti <ashishmadeti@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privatebroulik.de>
    SPDX-FileCopyrightText: 2019 Chris Holland <zrenfire@gmail.com>
    SPDX-FileCopyrightText: 2022 ivan (@ratijas) tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: GPL-2.0-or-later

    Simplified fork of org.kde.plasma.win7showdesktop for the Windows
    Modern theme. Removes command/mousewheel/peek-on-hover features;
    keeps the thin sliver rendering. Uses KWin's show-desktop mode (the
    same state as Win+D) rather than minimizing windows one by one.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.3

import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    toolTipSubText: activeController.description

    // Windows 11 displays a sliver rather than a show-desktop glyph.
    Plasmoid.icon: ""
    Plasmoid.title: activeController.title
    Plasmoid.onActivated: activeController.toggle()

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Minimum must never exceed maximum: the old 32px minimum
    // overrode the 6px sliver and left a blank cell to the bell's right.
    readonly property int sliverSize: Math.max(1, Plasmoid.configuration.size)
    Layout.minimumWidth: vertical ? 0 : sliverSize
    Layout.minimumHeight: vertical ? sliverSize : 0
    Layout.maximumWidth: vertical ? Number.POSITIVE_INFINITY : sliverSize
    Layout.maximumHeight: vertical ? sliverSize : Number.POSITIVE_INFINITY
    Layout.preferredWidth: vertical ? Kirigami.Units.iconSizes.medium : sliverSize
    Layout.preferredHeight: vertical ? sliverSize : Kirigami.Units.iconSizes.medium
    Layout.fillWidth: vertical
    Layout.fillHeight: !vertical

    Plasmoid.constraintHints: Plasmoid.CanFillArea

    readonly property bool inPanel: [PlasmaCore.Types.TopEdge, PlasmaCore.Types.RightEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge]
            .includes(Plasmoid.location)

    readonly property bool horizontal: Plasmoid.location === PlasmaCore.Types.TopEdge || Plasmoid.location === PlasmaCore.Types.BottomEdge
    readonly property bool vertical: Plasmoid.location === PlasmaCore.Types.RightEdge || Plasmoid.location === PlasmaCore.Types.LeftEdge

    readonly property Controller activeController: showDesktopController

    ShowDesktopController {
        id: showDesktopController
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        // Qt automatically mirrors the right margin in right-to-left layouts.
        anchors.rightMargin: root.horizontal ? -panelMargins.panelEdgeMargin : 0
        anchors.bottomMargin: root.vertical ? -panelMargins.panelEdgeMargin : 0

        activeFocusOnTab: true
        hoverEnabled: true

        PanelMargins {
            id: panelMargins
        }

        onClicked: Plasmoid.activated();

        Keys.onPressed: {
            switch (event.key) {
            case Qt.Key_Space:
            case Qt.Key_Enter:
            case Qt.Key_Return:
            case Qt.Key_Select:
                if (!event.isAutoRepeat) Plasmoid.activated();
                event.accepted = true;
                break;
            }
        }

        Accessible.name: Plasmoid.title
        Accessible.description: toolTipSubText
        Accessible.role: Accessible.Button
        Accessible.onPressAction: Plasmoid.activated()

        DropArea {
            anchors.fill: parent
            onEntered: activateTimer.start()
            onExited: activateTimer.stop()
            onDropped: activateTimer.stop()
        }

        Timer {
            id: activateTimer
            interval: 250
            onTriggered: if (!root.activeController.active) Plasmoid.activated()
        }

        state: {
            if (mouseArea.containsPress) {
                return "pressed";
            } else if (mouseArea.containsMouse || mouseArea.activeFocus) {
                return "hover";
            } else {
                return "normal";
            }
        }

        // Win11 show-desktop: invisible by default. On hover, a short
        // line across half the panel thickness fades in. No
        // background fill, no separator line.
        Rectangle {
            id: hoverLine
            color: Plasmoid.configuration.edgeColor
                  || Qt.rgba(Kirigami.Theme.textColor.r,
                             Kirigami.Theme.textColor.g,
                             Kirigami.Theme.textColor.b, 0.5)
            width: root.vertical ? parent.width * 0.5 : 1
            height: root.vertical ? 1 : parent.height * 0.5
            anchors.centerIn: parent
            opacity: Plasmoid.containment.corona.editMode || mouseArea.state === "hover" || mouseArea.state === "pressed" ? 1 : 0
            Behavior on opacity { OpacityAnimator { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad } }
        }

        PlasmaCore.ToolTipArea {
            id: toolTip
            anchors.fill: parent
            mainText: Plasmoid.title
            subText: toolTipSubText
            textFormat: Text.PlainText
        }
    }
}
