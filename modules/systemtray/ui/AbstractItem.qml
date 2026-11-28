/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "js/controlMetrics.js" as ControlMetrics
import "js/trayMetrics.js" as TrayMetrics

PlasmaCore.ToolTipArea {
    id: abstractItem

    required property int index
    required property var model
    required property int status
    required property int effectiveStatus
    required property Item trayRoot
    required property SystemTrayState trayState
    property Item preloadHost: null
    property Item popupContentItem: null
    property GridView overflowGridView: null
    property int leadingSystemInset: 0
    property int trailingSystemInset: 0

    required property string itemId
    /*required*/ property alias text: label.text

    // subclasses need to bind these tooltip properties
    required mainText
    required subText
    required textFormat

    readonly property alias iconContainer: iconContainer
    readonly property int coreNativeRenderSize: trayRoot.coreNativeRenderSize
    readonly property bool inHiddenLayout: effectiveStatus === PlasmaCore.Types.PassiveStatus
    readonly property bool inVisibleLayout: effectiveStatus === PlasmaCore.Types.ActiveStatus

    // Real status icons remain owned by the underlying Plasma applets.
    // These three visible cells share the Quick Settings action and hover.
    readonly property bool groupedQuickSettings: inVisibleLayout &&
        (itemId === "org.kde.plasma.networkmanagement" ||
         itemId === "org.kde.plasma.volume" || itemId === "org.kde.plasma.battery")
    property bool effectivePressed: false

    HoverHandler {
        enabled: abstractItem.groupedQuickSettings
        onHoveredChanged: {
            if (hovered) abstractItem.trayRoot.hoveredQuickSetting = abstractItem;
            else if (abstractItem.trayRoot.hoveredQuickSetting === abstractItem) abstractItem.trayRoot.hoveredQuickSetting = null;
        }
    }

    // The panel draws the shared group background once behind all cells.

    // Keep these in sync with HiddenItems.qml
    readonly property int margins: Kirigami.Units.smallSpacing
    readonly property int maxTextLines: 2

    // input agnostic way to trigger the main action
    signal activated(var pos)

    // proxy signals for MouseArea
    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)
    signal contextMenu(var mouse)

    PulseAnimation {
        targetItem: iconContainer
        running: (abstractItem.status === PlasmaCore.Types.NeedsAttentionStatus
                || abstractItem.status === PlasmaCore.Types.RequiresAttentionStatus)
            && Kirigami.Units.longDuration > 0
    }

    MouseArea {
        id: mouseArea
        propagateComposedEvents: true
        // This needs to be above applets when it's in the grid hidden area
        // so that it can receive hover events while the mouse is over an applet,
        // but below them on regular systray, so collapsing works
        z: abstractItem.inHiddenLayout || abstractItem.groupedQuickSettings ? 1 : 0
        anchors.fill: abstractItem
        hoverEnabled: true
        drag.filterChildren: true
        // Necessary to make the whole delegate area forward all mouse events
        acceptedButtons: Qt.AllButtons
        // Using onPositionChanged instead of onEntered because changing the
        // index in a scrollable view also changes the view position.
        // onEntered will change the index while the items are scrolling,
        // making it harder to scroll.
        onPositionChanged: if (abstractItem.inHiddenLayout) {
            const view = abstractItem.overflowGridView ?? abstractItem.trayRoot.hiddenLayout;
            if (view) view.currentIndex = abstractItem.index
        }
        onClicked: mouse => { abstractItem.clicked(mouse) }
        onPressed: mouse => {
            if (abstractItem.inHiddenLayout) {
                const view = abstractItem.overflowGridView ?? abstractItem.trayRoot.hiddenLayout;
                if (view) view.currentIndex = abstractItem.index
            }
            abstractItem.hideImmediately()
            abstractItem.pressed(mouse)
        }
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton) {
                abstractItem.contextMenu(mouse)
            }
        }
        onWheel: wheel => {
            // Only icons in the panel act on the wheel (scrolling over volume
            // or brightness adjusts it). In the flyout the cards are just
            // content: a touchpad scroll over "Brightness & Color" must not
            // change the brightness. Passing the event on would hand it to
            // the applet's own icon underneath (which does), so it is taken
            // here and scrolls the grid instead.
            if (abstractItem.inHiddenLayout) {
                const view = abstractItem.overflowGridView ?? abstractItem.trayRoot.hiddenLayout;
                if (!view) return;
                const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y
                                                    : wheel.angleDelta.y / 120 * view.cellHeight / 2;
                const bottom = view.originY + view.contentHeight - view.height;
                view.contentY = Math.max(view.originY, Math.min(view.contentY - dy, bottom));
                wheel.accepted = true;
                return;
            }
            abstractItem.wheel(wheel);
            //Don't accept the event in order to make the scrolling by mouse wheel working
            //for the parent scrollview this icon is in.
            wheel.accepted = false;
        }
    }

    // Icon-only overflow; retain native tooltips and accessible names.
    readonly property int overflowInset: Math.max(2, Math.round(4 * Plasmoid.configuration.scale / 100))
    readonly property bool activePanelApplet: abstractItem.trayState.expanded
        && !!abstractItem.trayState.activeApplet
        && abstractItem.trayState.activeApplet.parent?.container === abstractItem
    readonly property bool showItemHoverTile: abstractItem.inHiddenLayout
        || (abstractItem.inVisibleLayout && !abstractItem.groupedQuickSettings && !abstractItem.activePanelApplet
            && (mouseArea.containsMouse || mouseArea.containsPress || iconContainer.activeFocus))
    Rectangle {
        readonly property var panelRect: TrayMetrics.itemHoverRect(
            abstractItem.width, abstractItem.height, abstractItem.trayRoot.panelExtent, abstractItem.trayRoot.vertical)
        visible: abstractItem.showItemHoverTile
        x: abstractItem.inHiddenLayout ? 0 : panelRect.x
        y: abstractItem.inHiddenLayout ? 0 : panelRect.y
        width: abstractItem.inHiddenLayout ? abstractItem.width : panelRect.width
        height: abstractItem.inHiddenLayout ? abstractItem.height : panelRect.height
        radius: ControlMetrics.controlCornerRadius
        border.width: abstractItem.inHiddenLayout && mouseArea.containsMouse ? 1 : 0
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        color: {
            if (mouseArea.containsPress || abstractItem.effectivePressed)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10);
            if (mouseArea.containsMouse || iconContainer.activeFocus)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06);
            return "transparent";
        }
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        z: -1
    }

    ColumnLayout {
        anchors.fill: abstractItem
        // Overflow is icon-only; names remain in tooltips and accessibility.
        readonly property int leadingInset: abstractItem.groupedQuickSettings
            ? abstractItem.leadingSystemInset : 0
        readonly property int trailingInset: abstractItem.groupedQuickSettings
            ? abstractItem.trailingSystemInset : 0
        anchors.leftMargin: abstractItem.inHiddenLayout ? abstractItem.overflowInset
            : !abstractItem.trayRoot.vertical ? leadingInset : 0
        anchors.rightMargin: abstractItem.inHiddenLayout ? abstractItem.overflowInset
            : !abstractItem.trayRoot.vertical ? trailingInset : 0
        anchors.topMargin: abstractItem.inHiddenLayout ? abstractItem.overflowInset
            : abstractItem.trayRoot.vertical ? (abstractItem.trayRoot.reverseLayout ? trailingInset : leadingInset) : 0
        anchors.bottomMargin: abstractItem.inHiddenLayout ? abstractItem.overflowInset
            : abstractItem.trayRoot.vertical ? (abstractItem.trayRoot.reverseLayout ? leadingInset : trailingInset) : 0
        spacing: 0

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: 0
            Layout.verticalStretchFactor: 1
        }

        FocusScope {
            id: iconContainer
            scale: (abstractItem.effectivePressed || mouseArea.containsPress) ? 0.9 : 1

            activeFocusOnTab: !abstractItem.inHiddenLayout
            focus: true // Required in HiddenItemsView so keyboard events can be forwarded to this item
            Accessible.name: abstractItem.text
            Accessible.description: abstractItem.subText
            Accessible.role: Accessible.Button
            Accessible.onPressAction: abstractItem.activated(Plasmoid.popupPosition(iconContainer, iconContainer.width/2, iconContainer.height/2));

            Behavior on scale {
                ScaleAnimator {
                    duration: Kirigami.Units.shortDuration
                    easing.type: (abstractItem.effectivePressed || mouseArea.containsPress) ? Easing.OutCubic : Easing.InCubic
                }
            }

            Keys.onPressed: event => {
                switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                    case Qt.Key_Select:
                        abstractItem.activated(Plasmoid.popupPosition(iconContainer, width/2, height/2));
                        event.accepted = true;
                        break;
                    case Qt.Key_Menu:
                        abstractItem.contextMenu(null);
                        event.accepted = true;
                        break;
                }
            }

            property alias container: abstractItem
            property alias inVisibleLayout: abstractItem.inVisibleLayout
            readonly property int size: abstractItem.inVisibleLayout
                ? (abstractItem.groupedQuickSettings ? abstractItem.trayRoot.coreItemSize : abstractItem.trayRoot.itemSize)
                : Math.max(1, Math.min(
                Math.round(24 * Plasmoid.configuration.scale / 100),
                Math.floor(Math.min(abstractItem.width, abstractItem.height) - 2 * abstractItem.overflowInset)))

            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            // Native core applets need extra room for their own internal
            // icon padding. Other tray glyphs and overflow keep their sizes.
            // Text-based keyboard indicators retain the cell width.
            readonly property bool languageIndicator: abstractItem.inVisibleLayout
                && abstractItem.itemId === "org.kde.plasma.keyboardlayout"
            implicitWidth: languageIndicator && !abstractItem.trayRoot.vertical ? abstractItem.width
                : abstractItem.groupedQuickSettings && abstractItem.itemId === "org.kde.plasma.battery"
                    ? abstractItem.trayRoot.batteryContentWidth : size
            implicitHeight: languageIndicator && abstractItem.trayRoot.vertical ? abstractItem.height : size
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.maximumWidth: implicitWidth
            Layout.maximumHeight: implicitHeight
        }

        Item {
            Layout.preferredHeight: 0
            visible: false
        }

        PlasmaComponents3.Label {
            id: label

            Layout.fillWidth: true
            maximumLineCount: abstractItem.maxTextLines

            visible: false // The icon's accessible name still uses this text alias.

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            elide: Text.ElideRight
            textFormat: Text.PlainText
            wrapMode: Text.Wrap

            font.pixelSize: 10

            opacity: visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: 0
            Layout.verticalStretchFactor: 1
        }
    }
}
