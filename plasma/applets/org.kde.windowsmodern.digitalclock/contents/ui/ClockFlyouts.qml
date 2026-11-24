// SPDX-License-Identifier: GPL-2.0-or-later
// Two genuine native popup surfaces for the horizontal Windows taskbar.
// Each owns its KWin/Plasma background, border, shadow and blur region.
// Neither window individually closes on focus transfer to its sibling.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

Item {
    id: controller
    required property var clockApplet
    property Item anchorItem: null
    property bool opened: false
    property bool acquiredFocus: false
    readonly property bool horizontal: Plasmoid.location === PlasmaCore.Types.BottomEdge
        || Plasmoid.location === PlasmaCore.Types.TopEdge
    readonly property bool split: horizontal && calendarContent.flyoutTotalHeight >= 420
    readonly property bool opaque: (Plasmoid.containmentDisplayHints
        & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) !== 0
    readonly property int sectionGap: calendarContent.sectionGap
    readonly property int historyHeight: Math.max(80, calendarContent.flyoutTotalHeight
        - calendarWindow.wantedHeight - sectionGap - historyWindow.topPadding - historyWindow.bottomPadding)

    function open() {
        if (opened || !anchorItem || anchorItem.width <= 0 || anchorItem.height <= 0)
            return;
        acquiredFocus = false;
        opened = true;
        calendarWindow.applyGeometry();
        calendarWindow.visible = true;
        // Wait until the calendar's visual parent is mapped; native
        // positioning of the history popup uses that window's actual edge.
        Qt.callLater(() => {
            if (!controller.opened) return;
            controller.resize();
            calendarWindow.requestActivate();
            calendarContent.forceActiveFocus();
            controller.updateFocus();
        });
    }

    function close() {
        if (!opened) return;
        opened = false;
        dismissTimer.stop();
        historyWindow.visible = false;
        calendarWindow.visible = false;
        acquiredFocus = false;
    }

    function resize() {
        if (!opened) return;
        calendarWindow.applyGeometry();
        if (split) {
            historyWindow.applyGeometry();
            historyWindow.visible = true;
        } else {
            historyWindow.visible = false;
        }
    }

    function updateFocus() {
        if (!opened) return;
        if (calendarWindow.active || (split && historyWindow.active)) {
            acquiredFocus = true;
            dismissTimer.stop();
        } else if (acquiredFocus && !Plasmoid.configuration.pin) {
            // FocusChanged can temporarily be null when the pointer moves
            // between the two Wayland windows. Wait for the new focus owner.
            dismissTimer.restart();
        }
    }

    onSplitChanged: if (opened) close()

    Timer {
        id: dismissTimer
        interval: 180
        onTriggered: {
            if (controller.opened && !Plasmoid.configuration.pin
                    && !calendarWindow.active && (!controller.split || !historyWindow.active))
                controller.close();
        }
    }

    PlasmaCore.AppletPopup {
        id: calendarWindow
        objectName: "wmCalendarPopupWindow"
        visualParent: controller.anchorItem
        popupDirection: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge: return Qt.BottomEdge;
            case PlasmaCore.Types.LeftEdge: return Qt.RightEdge;
            case PlasmaCore.Types.RightEdge: return Qt.LeftEdge;
            default: return Qt.TopEdge;
        }
        margin: 8
        removeBorderStrategy: PlasmaCore.AppletPopup.Never
        backgroundHints: controller.opaque ? PlasmaCore.AppletPopup.SolidBackground
            : PlasmaCore.AppletPopup.StandardBackground
        hideOnWindowDeactivate: false
        animated: false
        visible: false
        readonly property int wantedWidth: Math.ceil(calendarContent.popupWidth + leftPadding + rightPadding)
        readonly property int wantedHeight: Math.ceil(calendarContent.popupHeight + topPadding + bottomPadding)
        function applyGeometry() {
            if (width !== wantedWidth) width = wantedWidth;
            if (height !== wantedHeight) height = wantedHeight;
        }
        onWantedWidthChanged: if (controller.opened) Qt.callLater(controller.resize)
        onWantedHeightChanged: if (controller.opened) Qt.callLater(controller.resize)
        onActiveChanged: controller.updateFocus()
        onVisibleChanged: if (!visible && controller.opened) controller.close()

        mainItem: ExpandedRepresentation {
            id: calendarContent
            clockApplet: controller.clockApplet
            calendarOnly: controller.split
            historyAnchorY: historyWindow.popupDirection === Qt.TopEdge
                ? -calendarWindow.topPadding : height + calendarWindow.bottomPadding - 1
        }
    }

    PlasmaCore.AppletPopup {
        id: historyWindow
        objectName: "wmNotificationPopupWindow"
        visualParent: calendarContent.historyAnchor
        popupDirection: calendarWindow.visible ? calendarWindow.effectivePopupDirection
            : calendarWindow.popupDirection
        margin: controller.sectionGap
        removeBorderStrategy: PlasmaCore.AppletPopup.Never
        backgroundHints: controller.opaque ? PlasmaCore.AppletPopup.SolidBackground
            : PlasmaCore.AppletPopup.StandardBackground
        hideOnWindowDeactivate: false
        animated: false
        visible: false

        readonly property int wantedWidth: Math.ceil(calendarContent.popupWidth + leftPadding + rightPadding)
        readonly property int wantedHeight: Math.ceil(controller.historyHeight + topPadding + bottomPadding)
        function applyGeometry() {
            if (width !== wantedWidth) width = wantedWidth;
            if (height !== wantedHeight) height = wantedHeight;
        }
        onWantedWidthChanged: if (controller.opened && controller.split) Qt.callLater(controller.resize)
        onWantedHeightChanged: if (controller.opened && controller.split) Qt.callLater(controller.resize)
        onActiveChanged: controller.updateFocus()
        onVisibleChanged: if (!visible && controller.opened && controller.split) controller.close()

        mainItem: FocusScope {
            id: notificationContent
            implicitWidth: calendarContent.popupWidth
            implicitHeight: controller.historyHeight
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: implicitWidth
            Layout.maximumWidth: implicitWidth
            Layout.minimumHeight: implicitHeight
            Layout.preferredHeight: implicitHeight
            Layout.maximumHeight: implicitHeight
            focus: true
            Keys.onEscapePressed: event => {
                controller.close();
                event.accepted = true;
            }

            NotificationHistory {
                anchors.fill: parent
                anchors.margins: 12
                currentTime: controller.clockApplet.currentTime
                notificationsAvailable: controller.clockApplet.notificationsAvailable
                effectiveDnd: controller.clockApplet.notificationsInhibited
                notificationModel: controller.clockApplet.notificationModel
                settings: controller.clockApplet.notificationSettings
                timeLocale: calendarContent.clockTimeLocale
                timeFormat: controller.clockApplet.timeFormat || "h:mm AP"
            }
        }
    }
}
