/*
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.private.digitalclock as DigitalClockPrivate
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import "code/dateformat.js" as DateFormat

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 10
    height: Kirigami.Units.gridUnit * 4

    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground | PlasmaCore.Types.ConfigurableBackground

    // Tooltips must not cover the notification/calendar flyout.
    // Owned by the actual compact representation in the panel window.
    property var panelPopup: null
    readonly property bool flyoutOpen: !!panelPopup && panelPopup.visible
    // The existing tray plugin already supplies rounded, split-window blur.
    // The clock is also installable on its own; never require that plugin.
    readonly property var splitBlurProvider: {
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (const applet of applets) {
            if (applet && applet.pluginName === "org.kde.windowsmodern.systemtray"
                    && typeof applet.setSplitPopupBlur === "function")
                return applet;
        }
        return null;
    }
    readonly property bool allowSplitAcrylic: (Plasmoid.containmentDisplayHints
        & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) === 0
    readonly property var popupScreenGeometry: Plasmoid.screenGeometry
    readonly property bool popupVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var popupPanelWindow: panelPopup && panelPopup.visualParent
        ? panelPopup.visualParent.Window.window : null
    readonly property real popupPanelExtent: popupPanelWindow
        ? (popupVerticalPanel ? popupPanelWindow.width : popupPanelWindow.height)
        : panelPopup && panelPopup.visualParent
            ? (popupVerticalPanel ? panelPopup.visualParent.width : panelPopup.visualParent.height) : 48
    toolTipMainText: flyoutOpen ? "" : i18n("Clock")
    toolTipSubText: flyoutOpen ? "" : notificationStatusText
    Plasmoid.status: flyoutOpen ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus

    function toggleFlyout(previous = flyoutOpen) {
        if (panelPopup) panelPopup.toggle(previous);
    }

    readonly property string currentTimeZone: currentClock.timeZone
    readonly property var currentTime: currentClock.dateTime

    // One shared history proxy for the bell and its existing flyout.
    // KDE's native notification applet still handles toast and job display.
    readonly property alias notificationModel: notificationModel
    readonly property alias notificationSettings: notificationSettings
    readonly property int unreadNotifications: notificationModel.unreadNotificationsCount
    readonly property bool notificationsAvailable: NotificationManager.Server.valid
    readonly property bool notificationsInhibited: NotificationManager.Server.inhibited
    readonly property string notificationIcon: !notificationsAvailable || notificationsInhibited
        ? "notifications-disabled-symbolic"
        : unreadNotifications > 0 ? "notification-active-symbolic" : "notification-inactive-symbolic"
    readonly property string notificationStatusText: !notificationsAvailable
        ? i18n("Notification service not available")
        : notificationsInhibited ? i18n("Do not disturb mode active")
        : unreadNotifications > 0
            ? i18np("%1 unread notification", "%1 unread notifications", unreadNotifications)
            : i18n("No unread notifications")

    NotificationManager.Settings { id: notificationSettings }

    readonly property alias focusSession: focusSessionState
    FocusSession {
        id: focusSessionState
        settings: root.notificationsAvailable ? notificationSettings : null
    }

    NotificationManager.Notifications {
        id: notificationModel
        showExpired: true
        showDismissed: true
        // Shared Plasma notifications and transfer jobs. Keep the native
        // applet loaded as the toast presenter, without its duplicate icon.
        showJobs: notificationSettings.jobsInNotifications
        showAddedDuringInhibition: true
        showNotifications: true
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 1
        expandUnread: false
        ignoreBlacklistDuringInhibition: true
        blacklistedDesktopEntries: notificationSettings.historyBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.historyBlacklistedServices
        // Popup filtering belongs to KDE's native toast presenter.
        // Notifications exposes history blacklist roles on Plasma 6.6–6.8.
        urgencies: NotificationManager.Notifications.CriticalUrgency
                 | NotificationManager.Notifications.NormalUrgency
                 | (notificationSettings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : 0)
    }

    onFlyoutOpenChanged: {
        if (flyoutOpen) {
            notificationModel.hideInhibitionSummary();
            notificationModel.lastRead = undefined;
        } else {
            notificationModel.collapseAllGroups();
        }
    }

    // Time format strings, updated by timeFormatCorrection().
    property string timeFormat
    property string timeFormatWithSeconds
    readonly property var clockTimeLocale: Plasmoid.configuration.use24hFormat === 1
        ? Qt.locale("en_US") : Qt.locale()

    // We need Local to be *always* present, even if not displayed, as it's
    // used for formatting and offset calculations.
    property list<string> allTimeZones

    PlasmaClock.Clock {
        id: currentClock
        timeZone: Plasmoid.configuration.lastSelectedTimezone
        // Second-by-second only while seconds are on screen: the flyout's
        // large clock shows them (it showed :00 with minute updates).
        trackSeconds: (root.flyoutOpen && Plasmoid.configuration.showTimeInNotificationCenter)
            || Plasmoid.configuration.showSeconds === 2
    }

    PlasmaClock.Clock {
        id: systemClock
        // No timezone defined: tracks the system timezone.
    }

    function initTimeZones() {
        const timeZones = [];
        if (Plasmoid.configuration.selectedTimeZones.indexOf("Local") === -1) {
            timeZones.push("Local");
        }
        root.allTimeZones = timeZones.concat(Plasmoid.configuration.selectedTimeZones);
    }

    function formatTime(dateTime: date, showSeconds: bool): string {
        let formattedTime;
        if (showSeconds) {
            formattedTime = root.clockTimeLocale.toString(dateTime, root.timeFormatWithSeconds);
        } else {
            formattedTime = root.clockTimeLocale.toString(dateTime, root.timeFormat);
        }

        // If the date differs from the current clock's date, append the day name.
        if (dateTime.getFullYear() !== currentClock.dateTime.getFullYear()
                || dateTime.getMonth() !== currentClock.dateTime.getMonth()
                || dateTime.getDate() !== currentClock.dateTime.getDate()) {
            formattedTime += " " + Qt.locale().toString(dateTime, "dddd");
        }

        return formattedTime;
    }

    function formatOffset(dateTime: date): string {
        const offset = Math.round((dateTime - currentClock.dateTime) / (1000 * 60));

        if (offset === 0) {
            return "";
        }

        // Math.floor rounds negative values away from zero (-7.5 → -8), so
        // take the absolute value first.
        const hourOffset = Math.floor(Math.abs(offset) / 60);
        // % keeps the sign of the dividend; the sign is already expressed by
        // "later"/"earlier", so render "7:30 earlier", not "7:-30 earlier".
        const minuteOffset = Math.abs(offset % 60);

        if (offset > 0) {
            if (minuteOffset === 0) {
                return i18ncp("@info offset from current time", " • %1 hour later", " • %1 hours later", hourOffset);
            } else {
                return i18nc("@info offset from current time in hours and minutes", " • %1:%2 later", hourOffset, minuteOffset);
            }
        } else {
            if (minuteOffset === 0) {
                return i18ncp("@info offset from current time", " • %1 hour earlier", " • %1 hours earlier", hourOffset);
            } else {
                return i18nc("@info offset from current time in hours and minutes", " • %1:%2 earlier", hourOffset, minuteOffset);
            }
        }
    }

    function selectedTimeZonesDeduplicatingExplicitLocalTimeZone(): /* [string] */ var {
        // Suppress duplicates when the user has added their local city explicitly
        // and is currently back in their normal local time zone.
        const isLiterallyLocalOrResolvesToSomethingOtherThanLocal = timeZone =>
            timeZone === "Local" || timeZone !== systemClock.timeZone;

        return DigitalClockPrivate.TimeZoneUtils.sortedTimeZones(
            Plasmoid.configuration.selectedTimeZones.filter(isLiterallyLocalOrResolvesToSomethingOtherThanLocal));
    }

    // Computes time format strings based on locale and user settings.
    function timeFormatCorrection(timeFormatString = Qt.locale().timeFormat(Locale.ShortFormat)) {
        const formats = DateFormat.clockFormats(Plasmoid.configuration.use24hFormat, timeFormatString);
        root.timeFormat = formats.time;
        root.timeFormatWithSeconds = formats.seconds;
    }

    // Same shell-role Dialog used by Start. AppletPopup always draws one
    // shared frame; Dialog.NoBackground permits a genuinely clear gap.
    preferredRepresentation: compactRep
    compactRepresentation: compactRep
    fullRepresentation: compactRep
    Component {
        id: compactRep
        CompactRepresentation { plasmoidItem: root }
    }
    function closeFlyout() { if (panelPopup) panelPopup.visible = false; }
    activationTogglesExpanded: false
    Connections {
        target: Plasmoid
        function onActivated() { root.toggleFlyout(); }
    }

    Connections {
        target: Plasmoid.configuration
        function onSelectedTimeZonesChanged() {
            root.initTimeZones();
        }
        function onUse24hFormatChanged() {
            root.timeFormatCorrection();
        }
        function onShowSecondsChanged() {
            root.timeFormatCorrection();
        }
    }

    Component.onCompleted: {
        Plasmoid.configuration.selectedTimeZones =
            DigitalClockPrivate.TimeZoneUtils.sortedTimeZones(Plasmoid.configuration.selectedTimeZones);

        root.initTimeZones();
        root.timeFormatCorrection();
    }
}
