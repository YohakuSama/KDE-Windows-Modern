/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Account and power options popup for the Start footer. Rendered as
 *   an in-dialog floating panel (NOT a separate PlasmaComponents3.Menu
 *   window) so the parent dialog's hideOnWindowDeactivate does not fire
 *   and close the whole start menu.
 ***************************************************************************/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.sessions
import org.kde.kirigami as Kirigami

import "../code/startMenuMetrics.js" as Metrics
import "../code/controlMetrics.js" as ControlMetrics
import "../code/footerNavigation.js" as FooterNavigation

Item {
    id: root

    property Item visualParent
    property bool accountMode: false
    readonly property bool opened: popup.visible
    readonly property var options: [settingsOption, lockOption, logoutOption, switchOption,
                                    sleepOption, hibernateOption, shutdownOption, rebootOption]
    readonly property bool hasAnyPowerOption: sleepOption.visible || hibernateOption.visible
        || shutdownOption.visible || rebootOption.visible

    signal closed
    signal accountSettingsRequested
    signal actionInvoked

    FontMetrics { id: footerMetrics; font: Kirigami.Theme.defaultFont }

    function moveFocus(direction) {
        const available = options.map(option => option.visible && option.optionEnabled);
        const current = options.findIndex(option => option.activeFocus);
        const next = FooterNavigation.nextEnabledIndex(available, current, direction);
        if (next >= 0) {
            const option = options[next];
            option.forceActiveFocus();
            if (option.y < powerScroll.contentY) powerScroll.contentY = option.y;
            else if (option.y + option.height > powerScroll.contentY + powerScroll.height)
                powerScroll.contentY = Math.max(0, option.y + option.height - powerScroll.height);
        } else {
            popup.forceActiveFocus();
        }
    }

    function finishAction() {
        root.close();
        root.actionInvoked();
    }

    SessionManagement { id: sessionManager }

    function triggerShutdown() {
        if (sessionManager.canShutdown) {
            sessionManager.requestShutdown()
        }
    }

    // ── Invisible click-catcher that closes the popup when clicking ────
    // outside its content.  Covers the entire parent (rootItem FocusScope).
    MouseArea {
        id: clickCatcher
        anchors.fill: parent
        visible: popup.visible
        z: 90
        onClicked: root.close()
    }

    // ── The floating panel ─────────────────────────────────────────────
    StartMenuBackground {
        id: popup
        visible: false
        z: 100

        readonly property real panelWidth: Math.max(0, Math.min(
            root.width - 2 * Metrics.popupEdgeInset,
            Metrics.accountMenuMaximumWidth,
            Math.max(Metrics.shutdownMenuMinimumWidth, ...root.options.filter(option => option && option.visible)
                .map(option => footerMetrics.advanceWidth(option.label) + Metrics.shutdownMenuTextWidthPadding))))
        width: panelWidth
        height: Math.min(powerColumn.implicitHeight + 2 * Metrics.menuInset, Math.max(0, root.height - 2 * Metrics.popupEdgeInset))


        Flickable {
            id: powerScroll
            anchors.fill: parent
            anchors.margins: Metrics.menuInset
            contentWidth: width
            contentHeight: powerColumn.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            HoverHandler { id: powerHover }
            QQC2.ScrollBar.vertical: StartScrollBar {
                viewportHovered: powerHover.hovered
                scrolling: powerScroll.moving || powerScroll.flicking
            }

            Column {
                id: powerColumn
                width: powerScroll.width
                spacing: 0

            PowerOption {
                id: settingsOption
                visible: root.accountMode
                iconSource: "configure-symbolic"
                label: i18n("Account settings")
                onActivated: {
                    root.close();
                    root.accountSettingsRequested();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: lockOption
                visible: root.accountMode && sessionManager.canLock
                iconSource: "system-lock-screen-symbolic"
                label: i18n("Lock")
                optionEnabled: sessionManager.canLock
                onActivated: {
                    sessionManager.lock();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: logoutOption
                visible: root.accountMode
                iconSource: "system-log-out-symbolic"
                label: i18n("Sign out")
                optionEnabled: sessionManager.canLogout
                onActivated: {
                    sessionManager.requestLogout();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: switchOption
                visible: root.accountMode
                iconSource: "system-switch-user-symbolic"
                label: i18n("Switch user")
                optionEnabled: sessionManager.canSwitchUser && sessionManager.canLock
                onActivated: {
                    sessionManager.switchUser();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: sleepOption
                visible: !root.accountMode && sessionManager.canSuspend && Plasmoid.configuration.showSleepButton
                iconSource: "system-suspend-symbolic"
                label: i18n("Sleep")
                optionEnabled: sessionManager.canSuspend
                onActivated: {
                    sessionManager.suspend();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            // Optional E823 clock glyph from the original Windows font.
            // Confirm the exact 26H2 shell role during desktop acceptance.
            PowerOption {
                id: hibernateOption
                visible: !root.accountMode && sessionManager.canHibernate
                iconSource: "system-suspend-hibernate"
                label: i18n("Hibernate")
                optionEnabled: sessionManager.canHibernate
                onActivated: {
                    sessionManager.hibernate();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: shutdownOption
                visible: !root.accountMode && sessionManager.canShutdown
                iconSource: "system-shutdown-symbolic"
                label: i18n("Shut down")
                optionEnabled: sessionManager.canShutdown
                onActivated: {
                    sessionManager.requestShutdown();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PowerOption {
                id: rebootOption
                visible: !root.accountMode && sessionManager.canReboot && Plasmoid.configuration.showRestartButton
                iconSource: "system-reboot-symbolic"
                label: i18n("Restart")
                optionEnabled: sessionManager.canReboot
                onActivated: {
                    sessionManager.requestReboot();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            PlasmaComponents3.Label {
                visible: !root.accountMode && !root.hasAnyPowerOption
                width: powerColumn.width
                padding: Metrics.menuTextInset
                text: i18n("There are currently no power options available.")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Kirigami.Theme.disabledTextColor
                font: footerMetrics.font
            }
            }
        }

        // Consume unhandled keys while the popup owns focus, rather than
        // accidentally sending printable characters or shortcuts to Start search.
        Keys.onPressed: event => {
            event.accepted = true;
            if (event.key === Qt.Key_Escape) {
                root.close();
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                root.moveFocus(-1);
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                root.moveFocus(event.modifiers & Qt.ShiftModifier ? -1 : 1);
            }
        }

        Behavior on opacity { NumberAnimation { duration: ControlMetrics.microInteractionDuration } }
    }

    // ── Positioning logic ──────────────────────────────────────────────
    onWidthChanged: if (popup.visible) close()
    onHeightChanged: if (popup.visible) close()

    function open() {
        if (!root.visualParent || !root.visualParent.visible || root.width <= 16 || root.height <= 16) return

        // Lay out only the active menu's visible rows before measuring.
        popup.visible = true;
        powerColumn.forceLayout();
        powerScroll.contentY = 0;
        var popupW = popup.width
        var popupH = popup.height
        var gap = Metrics.shutdownMenuAnchorGap

        // Account opens at the leading edge; Power stays at the trailing edge.
        const alignLeft = root.accountMode !== root.visualParent.LayoutMirroring.enabled;
        var pos = root.visualParent.mapToItem(root, alignLeft ? 0 : root.visualParent.width - popupW, -popupH - gap)

        // If the popup would go above the top of the dialog, open below
        // the button instead.
        if (pos.y < gap) {
            pos.y = root.visualParent.mapToItem(root, 0, root.visualParent.height + gap).y
        }

        // Clamp horizontally — keep the popup within the dialog bounds.
        pos.x = Math.max(gap, Math.min(pos.x, root.width - popupW - gap))

        popup.x = pos.x
        popup.y = Math.max(gap, Math.min(pos.y, root.height - popupH - gap))
        popup.opacity = 1
        // Mouse opening leaves every row neutral. Arrow/Tab selects the
        // first available row; no unsolicited accent-colour selection.
        popup.forceActiveFocus();
    }

    function close() {
        if (!popup.visible) return;
        popup.visible = false
        popup.opacity = 0
        root.closed()
    }
}
