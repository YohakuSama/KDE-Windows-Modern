/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Start button that creates and manages a PlasmaCore.Dialog popup.
 *   Pattern matches working plasmoids (Start.Next.Menu, menu.11.next).
 ***************************************************************************/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

Item {
    id: root

    readonly property var screenGeometry: Plasmoid.screenGeometry
    readonly property bool inPanel: (Plasmoid.location == PlasmaCore.Types.TopEdge
                                     || Plasmoid.location == PlasmaCore.Types.RightEdge
                                     || Plasmoid.location == PlasmaCore.Types.BottomEdge
                                     || Plasmoid.location == PlasmaCore.Types.LeftEdge)
    readonly property bool vertical: (Plasmoid.formFactor == PlasmaCore.Types.Vertical)
    readonly property bool useCustomButtonImage: (Plasmoid.configuration.useCustomButtonImage
                                                  && Plasmoid.configuration.customButtonImage.length != 0)
    property MenuRepresentation dashWindow: null
    property real logoScale: 1
    // Pointer release already owns its rebound. Keyboard and accessibility
    // activation synthesize a single press/release cycle instead.
    function activateStart(pointerActivation = false) {
        if (!dashWindow) return;
        if (!pointerActivation) {
            pressMotion.stop();
            releaseMotion.stop();
            settleMotion.stop();
            keyboardMotion.restart();
        }
        dashWindow.toggleMenu();
    }
    NumberAnimation {
        id: pressMotion
        target: root
        property: "logoScale"
        to: 0.84
        duration: Math.min(83, Kirigami.Units.shortDuration)
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: keyboardMotion
        NumberAnimation {
            target: root
            property: "logoScale"
            to: 0.84
            duration: Math.min(83, Kirigami.Units.shortDuration)
            easing.type: Easing.OutCubic
        }
        ScriptAction { script: releaseMotion.restart() }
    }
    NumberAnimation {
        id: settleMotion
        target: root
        property: "logoScale"
        to: 1
        duration: Math.min(167, Kirigami.Units.shortDuration)
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: releaseMotion
        NumberAnimation {
            target: root
            property: "logoScale"
            to: 1.035
            duration: Math.min(167, Kirigami.Units.shortDuration)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "logoScale"
            to: 1
            duration: Math.min(83, Kirigami.Units.shortDuration)
            easing.type: Easing.OutQuad
        }
    }

    Plasmoid.status: dashWindow && dashWindow.visible ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus

    // Expose the button to screen readers and accessibility tools: without
    // these the Start button is absent from the accessibility tree.
    Accessible.role: Accessible.Button
    Accessible.name: i18nc("@action:button the Start menu button", "Start")
    Accessible.description: i18nc("@info:tooltip", "Open the Start menu")
    Accessible.onPressAction: root.activateStart()

    // Use the same 30px icon canvas as task icons. The default logo keeps
    // its original 4px optical inset on the 64px artwork canvas.
    readonly property bool useDefaultLogo: !useCustomButtonImage && Plasmoid.configuration.icon === "start-here"
    readonly property int cellThickness: vertical ? width : height
    // Match the task icon canvas at 30 logical pixels, including the
    // original optical inset. Qt applies fractional output scaling.
    readonly property int startIconSize: inPanel
        ? Math.max(1, Math.min(30, cellThickness - 4, width, height))
        : Math.max(1, Math.min(width, height))

    // Hover (and open menu) tile: the taskbar's own tile without a bar
    // (tasks.svg "launcher-hover", as for a pinned app), for the panel edge.
    readonly property string edgePrefix: {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.TopEdge: return "north-";
        case PlasmaCore.Types.LeftEdge: return "west-";
        case PlasmaCore.Types.RightEdge: return "east-";
        default: return "";
        }
    }

    KSvg.FrameSvgItem {
        id: hoverTile
        anchors.fill: parent
        imagePath: "widgets/tasks"
        prefix: [root.edgePrefix + "launcher-hover", "launcher-hover", root.edgePrefix + "hover", "hover"]
        visible: root.inPanel && (mouseArea.containsMouse || (root.dashWindow?.menuShown ?? false))
    }

    Kirigami.Icon {
        id: buttonIcon

        anchors.centerIn: parent
        width: root.startIconSize
        height: root.startIconSize
        roundToIconSize: false
        source: useCustomButtonImage ? Plasmoid.configuration.customButtonImage
            : (root.useDefaultLogo ? Qt.resolvedUrl("start-logo.svg") : Plasmoid.configuration.icon)
        // Windows 11 does not lighten the logo on hover (the tile shows it);
        // pressing shrinks it slightly, like the other taskbar buttons.
        active: false
        scale: root.logoScale
        smooth: true
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true

        onPressed: {
            keyboardMotion.stop();
            settleMotion.stop();
            releaseMotion.stop();
            pressMotion.restart();
        }
        onCanceled: {
            pressMotion.stop();
            releaseMotion.stop();
            settleMotion.restart();
        }
        onReleased: {
            pressMotion.stop();
            if (containsMouse) releaseMotion.restart();
            else settleMotion.restart();
        }
        onClicked: root.activateStart(true)
    }

    // Register on the native Applet object, not a second launcher or
    // a shell scripting call. Search resolves this action on its own panel.
    PlasmaCore.Action {
        id: openSearchAction
        property var searchAnchor: null
        property bool taskbarBox: false
        text: i18n("Search")
        onTriggered: {
            if (root.dashWindow) root.dashWindow.openSearch(searchAnchor, taskbarBox);
            searchAnchor = null;
            taskbarBox = false;
        }
    }

    PlasmaCore.Action {
        id: searchStateAction
        enabled: root.dashWindow?.searchShown ?? false
    }

    Component.onCompleted: {
        dashWindow = menuRepComponent.createObject(root);
        Plasmoid.setInternalAction("windowsModernSearch", openSearchAction);
        Plasmoid.setInternalAction("windowsModernSearchSelected", searchStateAction);
        Plasmoid.activated.connect(function() {
            root.activateStart();
        });
    }

    Component {
        id: menuRepComponent
        MenuRepresentation {}
    }
}
