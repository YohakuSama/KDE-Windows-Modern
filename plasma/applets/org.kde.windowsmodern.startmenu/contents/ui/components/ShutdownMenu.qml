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
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.sessions
import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme
import "../code/footerNavigation.js" as FooterNavigation

Item {
    id: root

    property Item visualParent
    property bool accountMode: false
    readonly property bool opened: popup.visible
    readonly property rect popupGeometry: Qt.rect(popup.x, popup.y, popup.width, popup.height)
    readonly property int visibleOptionCount: options.filter(o => o.visible).length
    readonly property var options: [settingsOption, lockOption, switchOption, logoutOption,
                                    sleepOption, hibernateOption, shutdownOption, rebootOption]

    signal closed
    signal accountSettingsRequested
    signal actionInvoked

    function moveFocus(direction) {
        const available = options.map(option => option.visible && option.optionEnabled);
        const current = options.findIndex(option => option.activeFocus);
        const next = FooterNavigation.nextEnabledIndex(available, current, direction);
        if (next >= 0)
            options[next].forceActiveFocus();
        else
            popup.forceActiveFocus();
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
    StartMenuSurface {
        id: popup
        objectName: "wmStartFooterMenuSurface"
        visible: false
        z: 100

        // Measure ALL account and power labels, not just the currently
        // visible subset. Switching modes cannot change the shared width.
        readonly property real contentWidth: Math.max(0, ...root.options.map(o => o.implicitWidth))
        readonly property real panelWidth: Theme.actionMenuWidth(contentWidth, root.width)
        width: panelWidth
        height: powerColumn.implicitHeight + 2 * Theme.menuOuterInset

        Column {
            id: powerColumn
            width: Math.max(1, popup.panelWidth - 2 * Theme.menuOuterInset)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.menuOuterInset
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
                visible: root.accountMode
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
                id: sleepOption
                visible: !root.accountMode && sessionManager.canSuspend
                iconSource: "system-suspend-symbolic"
                label: i18n("Sleep")
                optionEnabled: sessionManager.canSuspend
                onActivated: {
                    sessionManager.suspend();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
            }

            // Preserve the distinct native hibernate icon until the
            // exact Windows shell glyph is verified.
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
                visible: !root.accountMode
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
                visible: !root.accountMode
                iconSource: "system-reboot-symbolic"
                label: i18n("Restart")
                optionEnabled: sessionManager.canReboot
                onActivated: {
                    sessionManager.requestReboot();
                    root.finishAction();
                }
                onNavigationRequested: direction => root.moveFocus(direction)
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

        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    // ── Positioning logic ──────────────────────────────────────────────
    function open() {
        if (!root.visualParent) return;
        if (popup.visible) { root.close(); return; }

        // Lay out only the active menu's visible rows before measuring.
        popup.visible = true;
        powerColumn.forceLayout();
        const anchor = root.visualParent.mapToItem(root, 0, 0);
        const leading = root.accountMode !== root.visualParent.LayoutMirroring.enabled;
        const position = Theme.actionMenuPosition(anchor.x, anchor.y,
            root.visualParent.width, root.visualParent.height,
            popup.width, popup.height, root.width, root.height, leading);
        popup.x = position.x;
        popup.y = position.y;
        popup.opacity = 1
        // Opening with the pointer must not pre-highlight the first row.
        // Up/Down/Tab select the first enabled action from this focus scope.
        popup.forceActiveFocus();
    }

    function close() {
        if (!popup.visible) return;
        popup.visible = false
        popup.opacity = 0
        root.closed()
    }
}
