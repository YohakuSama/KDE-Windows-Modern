/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "js/controlMetrics.js" as ControlMetrics

PlasmaCore.ToolTipArea {
    id: tooltip

    required property SystemTrayState trayState
    signal resetHiddenSelectionRequested()

    readonly property int arrowAnimationDuration: Kirigami.Units.shortDuration
    property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property int iconSize: 16
    property int cellLength: 32
    implicitWidth: vertical ? iconSize : cellLength
    implicitHeight: vertical ? cellLength : iconSize
    activeFocusOnTab: true

    Accessible.name: subText
    Accessible.description: i18n("Open or close the hidden icons popup")
    Accessible.role: Accessible.Button
    Accessible.onPressAction: tooltip.trayState.toggleHome(true)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            tooltip.trayState.toggleHome(true);
            event.accepted = true;
        }
    }

    subText: tooltip.trayState.overflowOpen ? i18n("Close popup") : i18n("Show hidden icons")

    property bool wasExpanded

    TapHandler {
        onPressedChanged: {
            if (pressed) {
                tooltip.wasExpanded = tooltip.trayState.overflowOpen;
            }
        }
        onTapped: (eventPoint, button) => {
            tooltip.trayState.toggleHome(true, tooltip.wasExpanded);
            tooltip.resetHiddenSelectionRequested();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: ControlMetrics.controlCornerRadius
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.08)
        visible: arrowHover.hovered || tooltip.trayState.overflowOpen
    }

    HoverHandler { id: arrowHover }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: tooltip.iconSize
        height: width

        isMask: true
        color: Kirigami.Theme.textColor
        roundToIconSize: false
        rotation: tooltip.trayState.overflowOpen ? 180 : 0
        Behavior on rotation {
            RotationAnimation {
                duration: tooltip.arrowAnimationDuration
                direction: RotationAnimation.Shortest
            }
        }

        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "arrow-down-symbolic";
            } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                return "arrow-right-symbolic";
            } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
                return "arrow-left-symbolic";
            } else {
                return "arrow-up-symbolic";
            }
        }
    }
}
