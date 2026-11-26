/*
    SPDX-FileCopyrightText: 2016 Marco Martin <mart@koyotic.space>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

import "components" as Components
import "js/trayMetrics.js" as TrayMetrics

Item {
    id: popup

    // Use the same native accent palette as every other shell surface.
    readonly property color shellAccent: Kirigami.Theme.highlightColor

    // Never derive the window's initial size from an effectively hidden
    // QQuickLayout. The native popup is sized before the window is mapped.
    readonly property bool overflowHome: systemTrayState.overflowMode && !systemTrayState.activeApplet
    readonly property rect screenRect: Plasmoid.screenGeometry
    readonly property int availableWidth: screenRect.width >= 100
        ? Math.max(1, Math.floor(screenRect.width - (root.vertical ? root.panelExtent : 0) - 24)) : 720
    readonly property int availableHeight: screenRect.height >= 100
        ? Math.max(1, Math.floor(screenRect.height - (root.vertical ? 0 : root.panelExtent) - 24)) : 720
    // The configured scale is a ceiling. Small work areas shrink the grid
    // before mapping, without using physical DPI or depending on panel length.
    readonly property real uiScale: Math.max(0.35, Math.min(Plasmoid.configuration.scale / 100,
        availableWidth / (quickHome || quickDetail ? TrayMetrics.quickPanelWidth : TrayMetrics.standardFlyoutWidth),
        availableHeight / TrayMetrics.quickDetailMinimumHeight))
    readonly property bool quickHome: !systemTrayState.activeApplet && !systemTrayState.overflowMode
    // One rounded settings card for home and all themed detail pages. Never
    // switch between KSVG frame insets and our card when navigating.
    readonly property bool customCard: quickHome || themedActive
    readonly property bool quickDetail: themedActive && systemTrayState.quickSettingsRoute
    readonly property int frameWidth: customCard ? 0 : Math.round(dialog.margins.left + dialog.margins.right)
    readonly property int frameHeight: customCard ? 0 : Math.round(dialog.margins.top + dialog.margins.bottom)
    readonly property int popupWidth: TrayMetrics.flyoutWidth(availableWidth, uiScale,
        overflowHome, frameWidth, quickHome || quickDetail)
    readonly property int overflowHeight: Math.max(1, Math.min(3, hiddenItemsView.rows))
        * Math.max(24, Math.round((popupWidth - 16 * uiScale) / 5))
        + Math.round(16 * uiScale)
    Mpris.Mpris2Model { id: mediaModel }
    readonly property int mediaGap: Math.round(TrayMetrics.mediaCardGap * uiScale)
    readonly property int mediaHeight: Math.round(TrayMetrics.mediaCardHeight * uiScale)
    readonly property bool separatedMedia: !systemTrayState.activeApplet && !systemTrayState.overflowMode
        && mediaCard.hasSession && availableHeight >= actionPanel.nominalHomeHeight + mediaGap + mediaHeight
    readonly property int quickCardHeight: TrayMetrics.quickSettingsHeight(availableHeight,
        actionPanel.nominalHomeHeight, quickDetail
            ? Math.round(TrayMetrics.quickDetailMinimumHeight * uiScale) : 0)
    readonly property int popupHeight: Math.max(1, Math.min(availableHeight - frameHeight,
        overflowHome ? overflowHeight
        : quickHome || quickDetail ? quickCardHeight + (separatedMedia ? mediaGap + mediaHeight : 0)
        : Math.max(360, Kirigami.Units.gridUnit * 24)))

    implicitWidth: popupWidth
    implicitHeight: popupHeight
    Layout.minimumWidth: popupWidth
    Layout.preferredWidth: popupWidth
    Layout.maximumWidth: popupWidth
    Layout.minimumHeight: popupHeight
    Layout.preferredHeight: popupHeight
    Layout.maximumHeight: popupHeight

    // The native Dialog suppresses its rectangular blur when NoBackground
    // is selected. Enable only the two rounded card regions after layout.
    property bool splitAcrylic: false
    readonly property bool allowSplitAcrylic: (Plasmoid.containmentDisplayHints
        & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) === 0

    function scheduleSplitBlur() {
        if (customCard && dialog.visible) splitBlurTimer.restart();
        else {
            splitBlurTimer.stop();
            splitAcrylic = false;
        }
    }
    Timer {
        id: splitBlurTimer
        interval: 16
        onTriggered: {
            if (!popup.customCard || !dialog.visible) {
                popup.splitAcrylic = false;
                return;
            }
            // Reuse the same compositor region helper for one or two
            // cards. Unioning the settings card with itself is intentional.
            popup.splitAcrylic = Plasmoid.setSplitPopupBlur(popup,
                popup.separatedMedia ? mediaCard : settingsSurface, settingsSurface,
                mediaCard.radius, popup.allowSplitAcrylic);
        }
    }
    onSeparatedMediaChanged: scheduleSplitBlur()
    onCustomCardChanged: scheduleSplitBlur()
    onAllowSplitAcrylicChanged: scheduleSplitBlur()
    Connections {
        target: Plasmoid
        function onPopupBlurPreferencesChanged() { popup.scheduleSplitBlur(); }
    }
    onWidthChanged: scheduleSplitBlur()
    onHeightChanged: scheduleSplitBlur()

    property alias hiddenLayout: hiddenItemsView.layout
    property alias plasmoidContainer: container

    function resetQuickSettings() { actionPanel.resetScroll(); }

    function focusCurrentPage() {
        if (systemTrayState.activeApplet) {
            container.forceActiveFocus();
        } else if (overflowHome) {
            hiddenItemsView.layout.forceActiveFocus();
        } else {
            actionPanel.forceActiveFocus();
        }
    }

    readonly property bool themedActive: container.themedActive
    readonly property bool unknownActive: systemTrayState.activeApplet && !popup.themedActive

    readonly property var flyoutToPlugin: ({
        "network":    "org.kde.plasma.networkmanagement",
        "bluetooth":  "org.kde.plasma.bluetooth",
        "volume":     "org.kde.plasma.volume",
        "battery":    "org.kde.plasma.battery",
        "brightness": "org.kde.plasma.brightness"
    })

    function activateFlyout(name) {
        const pluginId = flyoutToPlugin[name]
        if (!pluginId) return
        const applet = Plasmoid.appletForPluginId(pluginId)
        if (applet) {
            systemTrayState.setActiveApplet(applet, undefined, "quick")
            return
        }
        const settings = {
            network: "kcm_networkmanagement", bluetooth: "kcm_bluetooth",
            volume: "kcm_pulseaudio", battery: "kcm_powerdevilprofilesconfig",
            brightness: "kcm_powerdevilprofilesconfig"
        }
        KCMUtils.KCMLauncher.openSystemSettings(settings[name])
    }

    // Header — only for unknown (non-themed) applets. Themed pages have their
    // own PageHeader; the action panel is self-contained.
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidHeading
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        visible: popup.unknownActive
        height: trayHeading.height + bottomPadding + container.headingHeight
        Behavior on height {
            NumberAnimation { duration: Kirigami.Units.shortDuration / 2; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        id: settingsSurface
        objectName: "wmSharedQuickSettingsCard"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: popup.quickHome ? popup.quickCardHeight : popup.popupHeight
        visible: popup.customCard
        radius: mediaCard.radius
        color: mediaCard.surfaceColor
        border.width: 1
        border.color: mediaCard.outlineColor
        // Observe the actual painted surface, not the intermediate layout.
        // A radius change can alter the blur mask without resizing the window.
        onXChanged: popup.scheduleSplitBlur()
        onYChanged: popup.scheduleSplitBlur()
        onWidthChanged: popup.scheduleSplitBlur()
        onHeightChanged: popup.scheduleSplitBlur()
        onRadiusChanged: popup.scheduleSplitBlur()
        z: -1
    }

    ColumnLayout {
        id: expandedRepresentation
        anchors.fill: parent
        spacing: plasmoidHeading.visible ? plasmoidHeading.bottomPadding : 0

        // Header content (unknown applets only)
        RowLayout {
            id: trayHeading
            Layout.fillWidth: true
            visible: plasmoidHeading.visible

            PlasmaComponents.ToolButton {
                id: backButton
                visible: systemTrayState.activeApplet && systemTrayState.activeApplet.expanded
                icon.name: mirrored ? "go-previous-symbolic-rtl" : "go-previous-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18nc("@action:button", "Go Back")
                KeyNavigation.down: container
                onClicked: if (typeof systemTrayState.activeApplet?.backAction !== "undefined" && systemTrayState.activeApplet.backAction.enabled) {
                    systemTrayState.activeApplet?.backAction.trigger()
                } else {
                    systemTrayState.setActiveApplet(null)
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                leftPadding: 0
                level: 1
                text: systemTrayState.activeApplet ? systemTrayState.activeApplet.plasmoid.title : i18n("Status and Notifications")
                maximumLineCount: 1
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            Repeater {
                id: primaryActionButtons
                model: actionsButton.applet ? actionsButton.applet.Plasmoid.contextualActions.filter(a => !a.isSeparator && a.priority === PlasmaCore.Action.HighPriority) : []
                delegate: PlasmaComponents.ToolButton {
                    id: actionButton
                    required property int index
                    required property PlasmaCore.Action modelData
                    property PlasmaCore.Action qAction: modelData
                    visible: qAction && qAction.visible
                    contentItem: Kirigami.Icon {
                        anchors.centerIn: parent
                        active: actionButton.hovered
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: actionButton.qAction ? actionButton.qAction.icon.name : ""
                    }
                    enabled: qAction && qAction.enabled
                    checkable: qAction && qAction.checkable
                    checked: qAction && qAction.checked
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: qAction ? qAction.text : ""
                    KeyNavigation.down: backButton.KeyNavigation.down
                    KeyNavigation.left: (index > 0) ? primaryActionButtons.itemAt(index - 1) : backButton
                    KeyNavigation.right: (index < primaryActionButtons.count - 1) ? primaryActionButtons.itemAt(index + 1) : actionsButton.visible ? actionsButton : actionsButton.KeyNavigation.right
                    PlasmaComponents.ToolTip { text: actionButton.text }
                    onClicked: if (qAction) qAction.trigger()
                }
            }

            PlasmaComponents.ToolButton {
                id: actionsButton
                visible: visibleActions > 0
                enabled: visibleActions > 1 || (singleAction && singleAction.enabled)
                checked: visibleActions > 1 ? configMenu.status !== PlasmaExtras.Menu.Closed : singleAction && singleAction.checked
                property QtObject applet: systemTrayState.activeApplet || root
                property int visibleActions: actions.length
                property PlasmaCore.Action singleAction: visibleActions === 1 && menuItemFactory.object ? menuItemFactory.object.action : null
                readonly property var actions: applet ? applet.plasmoid.contextualActions.filter(action => {
                    return action.visible && action.priority === PlasmaCore.Action.NormalPriority && action !== applet.plasmoid.internalAction("configure")
                }).reduce((dst, action, i, src) => {
                    if (!action.isSeparator) { const p = src[i - 1]; if (p?.isSeparator && dst.length > 0) dst.push(p); dst.push(action) }
                    return dst
                }, []) : []
                icon.name: "application-menu"
                checkable: visibleActions > 1 || (singleAction && singleAction.checkable)
                contentItem.opacity: visibleActions > 1
                display: PlasmaComponents.AbstractButton.IconOnly
                text: singleAction ? singleAction.text : i18n("More actions")
                Accessible.role: singleAction ? Accessible.Button : Accessible.ButtonMenu
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.right: configureButton.visible ? configureButton : configureButton.KeyNavigation.right
                Kirigami.Icon {
                    parent: actionsButton
                    anchors.centerIn: parent
                    active: actionsButton.hovered
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    source: actionsButton.singleAction !== null ? actionsButton.singleAction.icon.name : ""
                    visible: actionsButton.singleAction
                }
                onToggled: if (visibleActions > 1) { checked ? configMenu.openRelative() : configMenu.close() }
                onClicked: if (singleAction) singleAction.trigger()
                PlasmaComponents.ToolTip { text: actionsButton.text }
                PlasmaExtras.Menu { id: configMenu; visualParent: actionsButton; placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup }
                Instantiator {
                    id: menuItemFactory
                    model: actionsButton.actions
                    delegate: PlasmaExtras.MenuItem { id: menuItem; required property PlasmaCore.Action modelData; action: modelData }
                    onObjectAdded: (index, object) => configMenu.addMenuItem(object)
                    onObjectRemoved: (index, object) => configMenu.removeMenuItem(object)
                }
            }
            PlasmaComponents.ToolButton {
                id: configureButton
                icon.name: "configure"
                visible: actionsButton.applet && actionsButton.applet.plasmoid.internalAction("configure")
                display: PlasmaComponents.AbstractButton.IconOnly
                text: {
                    const a = actionsButton.applet
                    const action = a ? a.plasmoid.internalAction("configure") : null
                    return action ? action.text : ""
                }
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.left: actionsButton.visible ? actionsButton : actionsButton.KeyNavigation.left
                KeyNavigation.right: pinButton
                PlasmaComponents.ToolTip { text: parent.visible ? parent.text : "" }
                onClicked: actionsButton.applet.plasmoid.internalAction("configure").trigger()
            }
            PlasmaComponents.ToolButton {
                id: pinButton
                checkable: true
                checked: Plasmoid.configuration.pin
                onToggled: Plasmoid.configuration.pin = checked
                icon.name: "window-pin"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Keep Open")
                KeyNavigation.down: backButton.KeyNavigation.down
                KeyNavigation.left: configureButton.visible ? configureButton : configureButton.KeyNavigation.left
                KeyNavigation.tab: container.currentItem?.nextItemInFocusChain() ?? null
                PlasmaComponents.ToolTip { text: parent.text }
            }
        }

        // The same popup hosts two separate homes: overflow OR Quick Settings.
        ColumnLayout {
            id: actionPanelMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !systemTrayState.activeApplet
            spacing: 0

            HiddenItemsView {
                id: hiddenItemsView
                Layout.fillWidth: true
                Layout.preferredHeight: hiddenItemsView.contentRowsHeight
                Layout.leftMargin: Math.round(8 * actionPanel.uiScale)
                Layout.rightMargin: Math.round(8 * actionPanel.uiScale)
                Layout.topMargin: Math.round(8 * actionPanel.uiScale)
                Layout.bottomMargin: Math.round(8 * actionPanel.uiScale)
                visible: popup.overflowHome && root.hiddenLayout.itemCount > 0
                KeyNavigation.up: pinButton
                onVisibleChanged: {
                    if (visible) {
                        layout.forceActiveFocus()
                        systemTrayState.oldVisualIndex = systemTrayState.newVisualIndex = -1
                    }
                }
            }

            Components.MediaCard {
                id: mediaCard
                Layout.fillWidth: true
                Layout.preferredHeight: popup.mediaHeight
                Layout.minimumHeight: popup.mediaHeight
                Layout.maximumHeight: popup.mediaHeight
                Layout.bottomMargin: popup.mediaGap
                uiScale: popup.uiScale
                player: mediaModel.currentPlayer
                acrylic: popup.splitAcrylic
                visible: popup.separatedMedia
                onXChanged: popup.scheduleSplitBlur()
                onYChanged: popup.scheduleSplitBlur()
                onWidthChanged: popup.scheduleSplitBlur()
                onHeightChanged: popup.scheduleSplitBlur()
            }

            Item {
                id: settingsCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: popup.quickCardHeight
                Layout.minimumHeight: popup.quickCardHeight
                Layout.maximumHeight: popup.quickCardHeight
                visible: !systemTrayState.overflowMode
                ActionPanel {
                    id: actionPanel
                    anchors.fill: parent
                    uiScale: popup.uiScale
                    availableHeight: popup.availableHeight
                    frameInset: 0
                    shellAccent: popup.shellAccent
                    onVisibleChanged: {
                        if (visible && dialog.visible && !systemTrayState.activeApplet)
                            forceActiveFocus();
                    }
                    onRequestPage: name => popup.activateFlyout(name)
                }
            }
        }

        // Container for the active applet (themed or unknown)
        PlasmoidPopupsContainer {
            id: container
            shellAccent: popup.shellAccent
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: systemTrayState.activeApplet
            Layout.topMargin: popup.themedActive || mergeHeadings ? 0 : dialog.margins.top
            Layout.minimumWidth: popup.themedActive ? 0 : Kirigami.Units.gridUnit * 12
            Layout.minimumHeight: popup.themedActive ? 0 : Kirigami.Units.gridUnit * 12
            KeyNavigation.up: pinButton
            KeyNavigation.backtab: pinButton
            onVisibleChanged: if (visible) forceActiveFocus()
        }
    }

    // Merged PlasmoidHeading footer — only for unknown applets that have one.
    PlasmaExtras.PlasmoidHeading {
        id: plasmoidFooter
        position: PlasmaComponents.ToolBar.Footer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        visible: popup.unknownActive && container.appletHasFooter
        height: container.footerHeight
        z: -9999
    }
}
