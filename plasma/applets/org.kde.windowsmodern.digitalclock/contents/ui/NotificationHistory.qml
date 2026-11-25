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
    required property date currentTime
    required property bool notificationsAvailable
    required property bool effectiveDnd
    property var timeLocale: Qt.locale()
    property string timeFormat: "h:mm AP"
    spacing: 8
    readonly property int minimumSectionHeight: Math.ceil(historyHeader.implicitHeight + spacing + 32)

    Win11Palette { id: palette }

    required property var notificationModel
    required property var settings

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
        id: historyHeader
        Layout.fillWidth: true
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
            quiet: true
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
            quiet: true
            text: i18n("Clear all")
            enabled: notificationModel.count > 0
            onClicked: history.clearAll()
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: 32
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: history.notificationsAvailable ? i18n("No notifications") : i18n("Notification service not available")
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
        Layout.preferredHeight: Math.max(32, contentHeight)
        visible: count > 0
        model: notificationModel
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: FluentScrollBar { objectName: "wmNotificationScrollBar" }
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
                    radius: 4
                    color: palette.cardTint

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
                                    const created = card.model.created;
                                    if (!created || isNaN(created.getTime())) return "";
                                    const sameDay = created.toDateString() === history.currentTime.toDateString();
                                    return (sameDay ? "" : history.timeLocale.toString(created, "yyyy/M/d") + " ")
                                        + history.timeLocale.toString(created, history.timeFormat);
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
                            color: palette.text
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            maximumLineCount: card.bodyExpanded ? 10 : 2
                            elide: Text.ElideRight
                            visible: !card.isGroup && text.length > 0
                        }

                        Flow {
                            id: actions
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            visible: !card.isGroup && !card.model.expired && (card.model.hasDefaultAction
                                || (card.model.actionNames || []).length > 0)

                            FlyoutButton {
                                readonly property string actionLabel: card.model.defaultActionLabel || i18n("Open")
                                text: actionLabel
                                visible: card.model.hasDefaultAction
                                    && !(card.model.actionLabels || []).includes(actionLabel)
                                width: Math.min(implicitWidth, actions.width)
                                onClicked: card.invoke("default")
                            }

                            Repeater {
                                model: card.model.actionNames || []
                                delegate: FlyoutButton {
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
                                Layout.minimumHeight: palette.controlHeight
                                leftPadding: 10
                                rightPadding: 10
                                font: Kirigami.Theme.defaultFont
                                color: palette.text
                                placeholderTextColor: palette.textSecondary
                                background: Rectangle {
                                    radius: palette.controlRadius
                                    color: palette.controlFill
                                    border.width: 1
                                    border.color: palette.controlBorder
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 2
                                        height: replyInput.activeFocus ? 2 : 1
                                        radius: 1
                                        color: replyInput.activeFocus ? palette.accent : palette.switchOutline
                                    }
                                }
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
