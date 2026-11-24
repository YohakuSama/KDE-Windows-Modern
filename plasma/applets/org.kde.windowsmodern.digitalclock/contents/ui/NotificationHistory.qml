/*
    SPDX-FileCopyrightText: 2026 Windows Modern contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.notificationmanager as NotificationManager

// Use Plasma's shared notification history, not a second notification server
// or a watcher that only sees notifications received after opening.
ColumnLayout {
    id: history
    property bool opened: false
    required property date currentTime
    spacing: Kirigami.Units.smallSpacing * 2

    Win11Palette { id: palette }

    NotificationManager.Settings { id: settings }

    NotificationManager.Notifications {
        id: notificationModel
        showExpired: true
        showDismissed: true
        // Keep file-copy/transfer jobs available through the native KDE applet.
        showJobs: false
        showNotifications: true
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 1
        expandUnread: false
        ignoreBlacklistDuringInhibition: true
        blacklistedDesktopEntries: settings.historyBlacklistedApplications
        blacklistedNotifyRcNames: settings.historyBlacklistedServices
        popupBlacklistedDesktopEntries: settings.popupBlacklistedApplications
        popupBlacklistedNotifyRcNames: settings.popupBlacklistedServices
        urgencies: NotificationManager.Notifications.CriticalUrgency
                 | NotificationManager.Notifications.NormalUrgency
                 | (settings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : 0)
    }

    function markRead() {
        if (opened) notificationModel.lastRead = undefined;
    }
    onOpenedChanged: {
        if (!opened) notificationModel.collapseAllGroups();
        markRead();
    }
    Component.onCompleted: markRead()

    // Respect automatic/application-driven DND; this button only controls the
    // user's manual setting, like the existing Quick Settings toggle.
    readonly property bool manualDnd: {
        const until = settings.notificationsInhibitedUntil;
        return until && !isNaN(until.getTime()) && until.getTime() > history.currentTime.getTime();
    }
    function toggleDnd() {
        if (manualDnd) {
            settings.notificationsInhibitedUntil = undefined;
        } else {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            settings.notificationsInhibitedUntil = until;
        }
        settings.save();
    }

    function clearAll() {
        // Take persistent indexes before closing anything: group rows can
        // disappear or move as their children are removed. Close a group only
        // once, including hidden children. KDE still checks each child's
        // closable state. Jobs never enter this notification model.
        const targets = [];
        for (let row = notificationModel.count - 1; row >= 0; --row) {
            const idx = notificationModel.index(row, 0);
            if (!notificationModel.data(idx, NotificationManager.Notifications.IsInGroupRole)
                    && notificationModel.data(idx, NotificationManager.Notifications.ClosableRole))
                targets.push(notificationModel.makePersistentModelIndex(idx));
        }
        for (const target of targets) {
            if (target && target.valid) {
                const idx = notificationModel.index(target.row, 0);
                notificationModel.close(idx);
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            text: i18n("Notifications")
            level: 2
            font.weight: Font.DemiBold
            color: palette.text
            elide: Text.ElideRight
        }

        PlasmaComponents.ToolButton {
            text: i18n("Manual do not disturb")
            icon.name: history.manualDnd ? "notifications-disabled" : "notifications"
            display: PlasmaComponents.AbstractButton.IconOnly
            checkable: true
            checked: history.manualDnd
            onClicked: history.toggleDnd()
            PlasmaComponents.ToolTip { text: parent.text }
        }

        PlasmaComponents.Button {
            text: i18n("Clear all")
            enabled: notificationModel.count > 0
            onClicked: history.clearAll()
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: i18n("No notifications")
        color: palette.textSecondary
        visible: notificationModel.count === 0
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 12,
            Math.max(Kirigami.Units.gridUnit * 4, contentHeight))
        visible: count > 0
        model: notificationModel
        spacing: Kirigami.Units.smallSpacing * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

        delegate: Rectangle {
            id: card
            required property int index
            required property var model
            readonly property bool isGroup: !!model.isGroup
            readonly property bool inGroup: !!model.isInGroup
            readonly property var notificationId: model.id
            onNotificationIdChanged: if (replyInput) replyInput.clear()
            width: list.width - Kirigami.Units.smallSpacing
            implicitHeight: content.implicitHeight + 2 * Kirigami.Units.largeSpacing
            height: implicitHeight
            radius: 8
            color: palette.surface
            border.width: 1
            border.color: palette.surfaceBorder

            function submitReply() {
                const text = replyInput.text;
                if (isGroup || !text.trim() || model.expired || !model.hasReplyAction) return;
                const idx = notificationModel.index(index, 0);
                const behavior = model.resident ? NotificationManager.Notifications.None
                                                : NotificationManager.Notifications.Close;
                replyInput.clear();
                notificationModel.reply(idx, text, behavior);
            }

            function invoke(name) {
                if (isGroup) return;
                const idx = notificationModel.index(index, 0);
                const behavior = model.resident ? NotificationManager.Notifications.None
                                                : NotificationManager.Notifications.Close;
                if (name === "default")
                    notificationModel.invokeDefaultAction(idx, behavior);
                else
                    notificationModel.invokeAction(idx, name, behavior);
            }

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        visible: !card.inGroup
                        source: card.model.applicationIconName || "preferences-desktop-notification"
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: card.inGroup ? "" : (card.model.applicationName || i18n("Notification"))
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: palette.textSecondary
                        font: Kirigami.Theme.smallFont
                    }
                    PlasmaComponents.Label {
                        text: card.isGroup ? i18np("%1 notification", "%1 notifications", card.model.groupChildrenCount || 0)
                            : card.model.created && !isNaN(card.model.created.getTime())
                                ? Qt.locale().toString(card.model.created, Locale.ShortFormat) : ""
                        color: palette.textSecondary
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 6
                    }
                    PlasmaComponents.ToolButton {
                        visible: card.isGroup
                        text: card.model.isGroupExpanded ? i18n("Show fewer") : i18n("Show more")
                        icon.name: card.model.isGroupExpanded ? "go-up" : "go-down"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: notificationModel.setData(notificationModel.index(card.index, 0),
                            !card.model.isGroupExpanded, NotificationManager.Notifications.IsGroupExpandedRole)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                    PlasmaComponents.ToolButton {
                        text: card.isGroup ? i18n("Dismiss group") : i18n("Dismiss notification")
                        icon.name: "window-close"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        visible: card.model.closable
                        onClicked: notificationModel.close(notificationModel.index(card.index, 0))
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.model.summary || ""
                    textFormat: Text.PlainText
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: !card.isGroup && text.length > 0
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: card.model.body || ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    visible: !card.isGroup && text.length > 0
                }

                Flow {
                    id: actions
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: !card.isGroup && !card.model.expired && (card.model.hasDefaultAction
                        || (card.model.actionNames || []).length > 0)

                    PlasmaComponents.Button {
                        readonly property string actionLabel: card.model.defaultActionLabel || i18n("Open")
                        text: actionLabel
                        visible: card.model.hasDefaultAction
                            && !(card.model.actionLabels || []).includes(actionLabel)
                        width: Math.min(implicitWidth, actions.width)
                        onClicked: card.invoke("default")
                    }

                    Repeater {
                        model: card.model.actionNames || []
                        delegate: PlasmaComponents.Button {
                            required property int index
                            required property string modelData
                            text: (card.model.actionLabels || [])[index] || modelData
                            width: Math.min(implicitWidth, actions.width)
                            onClicked: card.invoke(modelData)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !card.isGroup && !card.model.expired && !!card.model.hasReplyAction
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.TextField {
                        id: replyInput
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        placeholderText: card.model.replyPlaceholderText || i18n("Reply")
                        Accessible.name: card.model.replyActionLabel || i18n("Reply to notification")
                        onAccepted: card.submitReply()
                    }

                    PlasmaComponents.Button {
                        text: card.model.replySubmitButtonText || i18n("Send")
                        icon.name: card.model.replySubmitButtonIconName || "document-send"
                        enabled: replyInput.text.trim().length > 0
                        onClicked: card.submitReply()
                    }
                }
            }
        }
    }
}
