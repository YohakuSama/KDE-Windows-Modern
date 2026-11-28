/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtCore

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "js/controlMetrics.js" as ControlMetrics
import "js/trayMetrics.js" as TrayMetrics

PlasmaCore.ToolTipArea {
    id: tooltip

    required property SystemTrayState trayState
    signal resetHiddenSelectionRequested()

    readonly property int arrowAnimationDuration: Kirigami.Units.shortDuration > 0
        ? TrayMetrics.systemTrayChevronRotateDuration : 0
    property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property real panelExtent: 48
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
        id: arrowTap
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
        readonly property var hoverRect: TrayMetrics.itemHoverRect(
            tooltip.width, tooltip.height, tooltip.panelExtent, tooltip.vertical)
        x: hoverRect.x
        y: hoverRect.y
        width: hoverRect.width
        height: hoverRect.height
        radius: ControlMetrics.controlCornerRadius
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, arrowTap.pressed ? 0.10 : 0.06)
        visible: arrowHover.hovered || arrowTap.pressed || tooltip.trayState.overflowOpen || tooltip.activeFocus
    }

    HoverHandler { id: arrowHover }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: tooltip.iconSize
        height: width

        readonly property string arrowRole: {
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

        isMask: true
        color: Kirigami.Theme.textColor
        roundToIconSize: false
        active: false
        fallback: ""
        scale: arrowTap.pressed ? 0.9 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
        rotation: tooltip.trayState.overflowOpen ? 180 : 0
        Behavior on rotation {
            RotationAnimation {
                duration: tooltip.arrowAnimationDuration
                direction: RotationAnimation.Shortest
            }
        }

        source: {
            const nativeFile = StandardPaths.locate(StandardPaths.GenericDataLocation,
                "windows-modern/native-assets/icons/actions/" + arrowRole + ".svg",
                StandardPaths.LocateFile);
            return String(nativeFile).length > 0 ? nativeFile : arrowRole;
        }
    }
}
