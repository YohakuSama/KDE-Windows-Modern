/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: tooltip

    readonly property int arrowAnimationDuration: Kirigami.Units.shortDuration
    property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    implicitWidth: iconSize
    implicitHeight: iconSize
    activeFocusOnTab: true

    Accessible.name: subText
    Accessible.description: i18n("Show all the items in the system tray in a popup")
    Accessible.role: Accessible.Button
    Accessible.onPressAction: systemTrayState.toggleHome(true)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            systemTrayState.toggleHome(true);
            event.accepted = true;
        }
    }

    subText: systemTrayState.overflowOpen ? i18n("Close popup") : i18n("Show hidden icons")

    property bool wasExpanded

    TapHandler {
        onPressedChanged: {
            if (pressed) {
                tooltip.wasExpanded = systemTrayState.overflowOpen;
            }
        }
        onTapped: (eventPoint, button) => {
            systemTrayState.toggleHome(true, tooltip.wasExpanded);
            expandedRepresentation.hiddenLayout.currentIndex = -1;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.08)
        visible: arrowHover.hovered || systemTrayState.overflowOpen
    }

    HoverHandler { id: arrowHover }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: tooltip.iconSize
        height: width

        rotation: systemTrayState.overflowOpen ? 180 : 0
        Behavior on rotation {
            RotationAnimation {
                duration: tooltip.arrowAnimationDuration
            }
        }
        opacity: systemTrayState.overflowOpen ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: tooltip.arrowAnimationDuration
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

    Kirigami.Icon {
        anchors.centerIn: parent
        width: tooltip.iconSize
        height: width

        rotation: systemTrayState.overflowOpen ? 0 : -180
        Behavior on rotation {
            RotationAnimation {
                duration: tooltip.arrowAnimationDuration
            }
        }
        opacity: systemTrayState.overflowOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: tooltip.arrowAnimationDuration
            }
        }

        source: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
                return "arrow-up-symbolic";
            } else if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
                return "arrow-left-symbolic";
            } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
                return "arrow-right-symbolic";
            } else {
                return "arrow-down-symbolic";
            }
        }
    }
}
