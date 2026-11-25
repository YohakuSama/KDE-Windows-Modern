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
import org.kde.kcmutils as KCMUtils
import "code/dateformat.js" as DateFormat

// Use Plasma's shared notification history, not a second notification server
// or a watcher that only sees notifications received after opening.
ColumnLayout {
    id: history
    required property date currentTime
    readonly property string todayKey: currentTime.toDateString()
    required property bool notificationsAvailable
    required property bool effectiveDnd
    property var timeLocale: Qt.locale()
    property string timeFormat: "h:mm AP"
    spacing: 8
    // Size from the content, even before the shell-role window is mapped.
    // The parent caps the history height using the available screen area.
    readonly property int headerHeight: 28
    readonly property int emptyHeight: 64
    readonly property int dndHeight: Math.ceil(24 + 6 + Math.max(30, dndMessage.implicitHeight) + 8 + 22)
    // Reserve the same banner budget in both states. DND consumes space inside
    // the card, not by moving the popup or shrinking the calendar.
    readonly property int historyChromeHeight: headerHeight + spacing + dndHeight + spacing
    readonly property int minimumSectionHeight: historyChromeHeight + emptyHeight
    // The notification card keeps the Windows 11 empty-state height.
    // Notification count and body length affect only the inner scroll view.
    readonly property int preferredSectionHeight: minimumSectionHeight
    property int modelRevision: 0
    readonly property bool hasClearable: {
        const revision = modelRevision;
        for (let row = 0; row < notificationModel.count; ++row) {
            if (typeof notificationModel.get === "function") {
                if (notificationModel.get(row).closable) return true;
            } else if (notificationModel.data(notificationModel.index(row, 0), NotificationManager.Notifications.ClosableRole)) {
                return true;
            }
        }
        return false;
    }
    Connections {
        target: history.notificationModel
        ignoreUnknownSignals: true
        function onDataChanged() { history.modelRevision++; }
        function onModelReset() { history.modelRevision++; }
    }

    Win11Palette { id: palette }

    required property var notificationModel
    required property var settings

    // Respect automatic/application-driven DND; this button only controls the
    // user's manual setting; the notification center is its single entry.
    readonly property bool manualDnd: {
        const until = settings.notificationsInhibitedUntil;
        return !!until && !isNaN(until.getTime()) && until.getTime() > history.currentTime.getTime();
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
        // closable state, so clearing history never cancels running jobs.
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
        id: historyHeader
        Layout.fillWidth: true
        Layout.preferredHeight: history.headerHeight
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18n("Notifications")
            font.pixelSize: 14
            font.weight: Font.Medium
            color: palette.text
            elide: Text.ElideRight
        }

        FlyoutButton {
            Layout.preferredWidth: 28
            text: history.effectiveDnd && !history.manualDnd
                ? i18n("Do not disturb is active due to a rule or application")
                : i18n("Manual do not disturb")
            icon.name: "notification-disabled-symbolic"
            attentionActive: history.effectiveDnd
            enabled: history.notificationsAvailable
            display: PlasmaComponents.AbstractButton.IconOnly
            checkable: true
            checked: history.manualDnd
            onClicked: history.toggleDnd()
            PlasmaComponents.ToolTip { text: parent.text }
        }

        FlyoutButton {
            objectName: "wmClearNotifications"
            text: i18n("Clear all")
            visible: history.hasClearable
            enabled: visible
            onClicked: history.clearAll()
        }
    }

    Item {
        objectName: "wmDoNotDisturbBanner"
        Layout.fillWidth: true
        Layout.preferredHeight: history.dndHeight
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight
        visible: history.effectiveDnd

        RowLayout {
            id: dndTitle
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            spacing: 6
            Kirigami.Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: "notification-disabled-symbolic"
                isMask: true
                color: palette.text
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18n("Do not disturb is on")
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: palette.text
                elide: Text.ElideRight
            }
        }

        PlasmaComponents.Label {
            id: dndMessage
            anchors.top: dndTitle.bottom
            anchors.topMargin: 6
            width: Math.max(1, history.width)
            text: i18n("Only notifications allowed by your priority settings appear as banners.")
            color: palette.textSecondary
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        PlasmaComponents.Label {
            objectName: "wmNotificationSettingsLink"
            anchors.top: dndMessage.bottom
            anchors.topMargin: 8
            text: i18n("Notification settings")
            color: palette.accentLink
            font.pixelSize: 13
            font.underline: true
            activeFocusOnTab: true
            Accessible.role: Accessible.Link
            Accessible.name: text
            Accessible.onPressAction: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications")
            Keys.onReturnPressed: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications")
            Keys.onSpacePressed: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications")
            TapHandler { onTapped: KCMUtils.KCMLauncher.openSystemSettings("kcm_notifications") }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    PlasmaComponents.Label {
        objectName: "wmEmptyNotifications"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: history.emptyHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: history.notificationsAvailable ? i18n("No new notifications") : i18n("Notification service not available")
        color: palette.textSecondary
        font.pixelSize: 12
        visible: notificationModel.count === 0
    }

    ListView {
        id: list
        objectName: "wmNotificationList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: Math.max(history.emptyHeight, contentHeight)
        visible: count > 0
        interactive: contentHeight > height
        model: notificationModel
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        HoverHandler { id: listHover }
        QQC2.ScrollBar.vertical: FluentScrollBar {
            objectName: "wmNotificationScrollBar"
            viewportHovered: listHover.hovered
            scrolling: list.moving || list.flicking
        }
        Kirigami.WheelHandler {
            target: list
            filterMouseEvents: true
            blockTargetWheel: true
            keyNavigationEnabled: false
            verticalStepSize: 120
        }

        delegate: Item {
            id: card
            required property int index
            required property var model
            readonly property bool isGroup: !!model.isGroup
            readonly property bool inGroup: !!model.isInGroup
            readonly property bool isJob: model.type === NotificationManager.Notifications.JobType
            readonly property bool runningJob: isJob && model.jobState !== NotificationManager.Notifications.JobStateStopped
            readonly property var notificationId: model.id
            property bool bodyExpanded: false
            onNotificationIdChanged: {
                if (replyInput) replyInput.clear();
                bodyExpanded = false;
            }
            // Fixed gutter: content height must not control delegate width.
            width: Math.max(1, list.width - 12)
            implicitHeight: content.implicitHeight
            height: implicitHeight

            function submitReply() {
                const text = replyInput.text;
                if (isGroup || isJob || !text.trim() || model.expired || !model.hasReplyAction) return;
                const idx = notificationModel.index(index, 0);
                const behavior = model.resident ? NotificationManager.Notifications.None
                                                : NotificationManager.Notifications.Close;
                replyInput.clear();
                notificationModel.reply(idx, text, behavior);
            }

            function invoke(name) {
                if (isGroup || isJob || model.expired) return;
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
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    visible: !card.inGroup
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 6

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
                        color: palette.text
                        font.pixelSize: 12
                    }
                    PlasmaComponents.Label {
                        visible: card.isGroup
                        text: i18np("%1 notification", "%1 notifications", card.model.groupChildrenCount || 0)
                        color: palette.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.maximumWidth: 96
                    }
                    FlyoutButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        quiet: true
                        visible: card.isGroup
                        text: card.model.isGroupExpanded ? i18n("Show fewer") : i18n("Show more")
                        icon.name: card.model.isGroupExpanded ? "go-up" : "go-down"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: notificationModel.setData(notificationModel.index(card.index, 0),
                            !card.model.isGroupExpanded, NotificationManager.Notifications.IsGroupExpandedRole)
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                    FlyoutButton {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        quiet: true
                        text: card.isGroup ? i18n("Dismiss group") : i18n("Dismiss notification")
                        icon.name: "window-close"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        visible: card.model.closable
                        onClicked: notificationModel.close(notificationModel.index(card.index, 0))
                        PlasmaComponents.ToolTip { text: parent.text }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: !card.isGroup
                    implicitHeight: messageContent.implicitHeight + 20
                    radius: 8
                    color: palette.cardTint
                    border.width: 1
                    border.color: Qt.rgba(palette.text.r, palette.text.g, palette.text.b, 0.08)

                    ColumnLayout {
                        id: messageContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            PlasmaComponents.Label {
                                text: {
                                    const updated = card.model.updated;
                                    const created = card.model.created;
                                    const timestamp = updated && !isNaN(updated.getTime()) ? updated : created;
                                    if (!timestamp || isNaN(timestamp.getTime())) return "";
                                    const sameDay = timestamp.toDateString() === history.todayKey;
                                    return (sameDay ? "" : history.timeLocale.toString(timestamp, DateFormat.shortDateFullYear(history.timeLocale.dateFormat(Locale.ShortFormat))) + " ")
                                        + DateFormat.formatClockTime(history.timeLocale, timestamp, history.timeFormat);
                                }
                                color: palette.textSecondary
                                font.pixelSize: 11
                            }

                            FlyoutButton {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                quiet: true
                                visible: !!card.model.body
                                text: card.bodyExpanded ? i18n("Show fewer") : i18n("Show more")
                                icon.name: card.bodyExpanded ? "go-up-symbolic" : "go-down-symbolic"
                                display: PlasmaComponents.AbstractButton.IconOnly
                                onClicked: card.bodyExpanded = !card.bodyExpanded
                            }

                            Item { Layout.fillWidth: true }

                            FlyoutButton {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                quiet: true
                                visible: card.inGroup && card.model.closable
                                text: i18n("Dismiss notification")
                                icon.name: "window-close"
                                display: PlasmaComponents.AbstractButton.IconOnly
                                onClicked: history.notificationModel.close(history.notificationModel.index(card.index, 0))
                            }
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: card.model.summary || ""
                            textFormat: Text.PlainText
                            font.weight: Font.Medium
                            font.pixelSize: 13
                            color: palette.text
                            wrapMode: Text.Wrap
                            maximumLineCount: card.bodyExpanded ? 4 : 2
                            elide: Text.ElideRight
                            visible: !card.isGroup && text.length > 0
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: card.model.body || ""
                            textFormat: Text.StyledText
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            color: palette.text
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            maximumLineCount: card.bodyExpanded ? 10 : 2
                            elide: Text.ElideRight
                            visible: !card.isGroup && text.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: card.runningJob && !card.isGroup
                            QQC2.ProgressBar {
                                id: transferProgress
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                padding: 0
                                from: 0
                                to: 100
                                value: Math.max(0, Math.min(100, Number(card.model.percentage) || 0))
                                Accessible.name: i18n("Transfer progress")
                                background: Rectangle {
                                    radius: 2
                                    color: palette.progressTrack
                                }
                                contentItem: Item {
                                    Rectangle {
                                        anchors.left: transferProgress.mirrored ? undefined : parent.left
                                        anchors.right: transferProgress.mirrored ? parent.right : undefined
                                        width: parent.width * transferProgress.position
                                        height: parent.height
                                        radius: 2
                                        color: palette.accent
                                    }
                                }
                            }
                            PlasmaComponents.Label {
                                text: Math.round(Number(card.model.percentage) || 0) + "%"
                                color: palette.textSecondary
                                font.pixelSize: 12
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: card.runningJob && !card.isGroup
                            FlyoutButton {
                                visible: !!card.model.suspendable
                                text: card.model.jobState === NotificationManager.Notifications.JobStateSuspended
                                    ? i18n("Resume") : i18n("Pause")
                                onClicked: {
                                    const idx = history.notificationModel.index(card.index, 0);
                                    if (card.model.jobState === NotificationManager.Notifications.JobStateSuspended)
                                        history.notificationModel.resumeJob(idx);
                                    else
                                        history.notificationModel.suspendJob(idx);
                                }
                            }
                            FlyoutButton {
                                visible: !!card.model.killable
                                text: i18n("Cancel")
                                onClicked: history.notificationModel.killJob(history.notificationModel.index(card.index, 0))
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Flow {
                            id: actions
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            readonly property bool showDefault: !!card.model.hasDefaultAction
                                && !(card.model.actionLabels || []).includes(defaultAction.actionLabel)
                            readonly property int actionCount: (showDefault ? 1 : 0) + (card.model.actionNames || []).length
                            visible: !card.isGroup && !card.isJob && !card.model.expired && actionCount > 0

                            FlyoutButton {
                                id: defaultAction
                                readonly property string actionLabel: card.model.defaultActionLabel || i18n("Open")
                                text: actionLabel
                                visible: actions.showDefault
                                width: actions.actionCount === 1 ? actions.width : Math.min(implicitWidth, actions.width)
                                onClicked: card.invoke("default")
                            }

                            Repeater {
                                model: card.model.actionNames || []
                                delegate: FlyoutButton {
                                    required property int index
                                    required property string modelData
                                    text: (card.model.actionLabels || [])[index] || modelData
                                    width: actions.actionCount === 1 ? actions.width : Math.min(implicitWidth, actions.width)
                                    onClicked: card.invoke(modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: !card.isGroup && !card.isJob && !card.model.expired && !!card.model.hasReplyAction
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents.TextField {
                                id: replyInput
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                placeholderText: card.model.replyPlaceholderText || i18n("Reply")
                                Accessible.name: card.model.replyActionLabel || i18n("Reply to notification")
                                onAccepted: card.submitReply()
                            }

                            FlyoutButton {
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
    }
}
