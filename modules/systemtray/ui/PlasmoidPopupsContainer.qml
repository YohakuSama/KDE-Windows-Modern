/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@koyotic.space>
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "components" as Components
QQC2.StackView {
    id: mainStack
    focus: true
    required property Item trayRoot
    required property SystemTrayState trayState
    property color shellAccent: Kirigami.Theme.highlightColor

    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12

    readonly property Item activeApplet: trayState.activeApplet

    // Whether the active applet is one we render a themed flyout for.
    readonly property bool themedActive: !!(themedPages && themedPages[flyoutRouter.flyoutNameForApplet(activeApplet)])

    /* Heading — only relevant for unknown (non-themed) applets */
    property bool appletHasHeading: false
    property bool mergeHeadings: appletHasHeading && activeApplet && activeApplet.fullRepresentationItem && activeApplet.fullRepresentationItem.header && activeApplet.fullRepresentationItem.header.visible
    property int headingHeight: mergeHeadings ? activeApplet.fullRepresentationItem.header.height : 0
    /* Footer — only relevant for unknown applets (themed pages render their own) */
    property bool appletHasFooter: false
    property bool mergeFooters: appletHasFooter && activeApplet && activeApplet.fullRepresentationItem && activeApplet.fullRepresentationItem.footer && activeApplet.fullRepresentationItem.footer.visible
    property int footerHeight: mergeFooters ? activeApplet.fullRepresentationItem.footer.height : 0

    FlyoutRouter {
        id: flyoutRouter
    }

    onActiveAppletChanged: Qt.callLater(mainStack.showActiveApplet)

    // Native Bluetooth and device pages can create their full item after
    // activeAppletChanged. Retry on that actual signal, not a polling timer.
    Connections {
        target: mainStack.activeApplet
        function onFullRepresentationItemChanged() {
            if (!mainStack.themedActive)
                Qt.callLater(mainStack.showActiveApplet);
        }
    }

    function showActiveApplet() {
        mainStack.appletHasHeading = false
        mainStack.appletHasFooter = false

        // Read the current route directly after the applet has settled.
        // Derived themedActive may still describe the previous page.
        const name = flyoutRouter.flyoutNameForApplet(activeApplet);
        const comp = themedPages[name];
        if (comp) {
            const properties = {
                    "width": Qt.binding(() => mainStack.width),
                    "height": Qt.binding(() => mainStack.height),
                    "x": 0,
                    "focus": Qt.binding(() => !mainStack.busy),
                    "opacity": 1,
                    "KeyNavigation.up": mainStack.KeyNavigation.up,
                    "KeyNavigation.backtab": mainStack.KeyNavigation.backtab
            };
            if (mainStack.empty)
                mainStack.push(comp, properties, QQC2.StackView.Immediate);
            else
                mainStack.replace(comp, properties, QQC2.StackView.Immediate);
            return
        }

        if (activeApplet != null && activeApplet.fullRepresentationItem && !activeApplet.preferredRepresentation) {
            activeApplet.fullRepresentationItem.anchors.left = undefined
            activeApplet.fullRepresentationItem.anchors.top = undefined
            activeApplet.fullRepresentationItem.anchors.right = undefined
            activeApplet.fullRepresentationItem.anchors.bottom = undefined
            activeApplet.fullRepresentationItem.anchors.centerIn = undefined
            activeApplet.fullRepresentationItem.anchors.fill = undefined

            if (activeApplet.fullRepresentationItem instanceof PlasmaComponents3.Page ||
                activeApplet.fullRepresentationItem instanceof PlasmaExtras.Representation) {
                if (activeApplet.fullRepresentationItem.header && activeApplet.fullRepresentationItem.header instanceof PlasmaExtras.PlasmoidHeading) {
                    mainStack.appletHasHeading = true
                    if (activeApplet.fullRepresentationItem.header.background)
                        activeApplet.fullRepresentationItem.header.background.visible = false
                }
                if (activeApplet.fullRepresentationItem.footer && activeApplet.fullRepresentationItem.footer instanceof PlasmaExtras.PlasmoidHeading) {
                    mainStack.appletHasFooter = true
                    if (activeApplet.fullRepresentationItem.footer.background)
                        activeApplet.fullRepresentationItem.footer.background.visible = false
                }
            }

            // Do not push the same native view twice if its creation and
            // the applet activation queued the same update.
            const page = activeApplet.fullRepresentationItem;
            if (mainStack.currentItem === page)
                return;
            const properties = {
                "width": Qt.binding(() => mainStack.width),
                "height": Qt.binding(() => mainStack.height),
                "x": 0,
                "focus": Qt.binding(() => !mainStack.busy),
                "opacity": 1,
                "KeyNavigation.up": mainStack.KeyNavigation.up,
                "KeyNavigation.backtab": mainStack.KeyNavigation.backtab
            };
            if (mainStack.empty)
                mainStack.push(page, properties, QQC2.StackView.Immediate);
            else
                mainStack.replace(page, properties, QQC2.StackView.Immediate);
        } else {
            mainStack.clear(QQC2.StackView.Immediate)
        }
    }

    onCurrentItemChanged: {
        if (currentItem !== null && mainStack.trayRoot.expanded) {
            currentItem.forceActiveFocus()
        }
    }

    Connections {
        target: Plasmoid
        function onAppletRemoved(applet) {
            if (applet === mainStack.trayState.activeApplet) {
                mainStack.trayState.setActiveApplet(null)
                mainStack.clear(QQC2.StackView.Immediate)
            }
        }
    }

    readonly property var themedPages: ({
        "network":         networkPageComp,
        "bluetooth":       bluetoothPageComp,
        "volume":          volumePageComp,
        "battery":         batteryPageComp,
        "brightness":      brightnessPageComp,
        "clipboard":       clipboardPageComp,
        "mediacontroller": mediaControllerPageComp,
        "devices":          devicesPageComp
    })

    Component {
        id: bluetoothPageComp
        Components.BluetoothPage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }

    Component {
        id: networkPageComp
        Components.NetworkPage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }
    Component {
        id: volumePageComp
        Components.VolumePage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }
    Component {
        id: batteryPageComp
        Components.BatteryPage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }
    Component {
        id: brightnessPageComp
        Components.BrightnessPage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }
    Component {
        id: clipboardPageComp
        Components.ClipboardPage {
            onBack: mainStack.trayState.setActiveApplet(null)
            onItemSelected: {
                mainStack.trayState.expanded = false;
                if (typeof Plasmoid.restoreShellPopupFocus === "function")
                    Plasmoid.restoreShellPopupFocus();
            }
            onCloseRequested: {
                mainStack.trayState.expanded = false;
                if (typeof Plasmoid.restoreShellPopupFocus === "function")
                    Plasmoid.restoreShellPopupFocus();
            }
        }
    }
    Component {
        id: devicesPageComp
        Components.DevicesPage {
            nativeApplet: mainStack.activeApplet
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }

    Component {
        id: mediaControllerPageComp
        Components.MediaControllerPage {
            shellAccent: mainStack.shellAccent
            onBack: mainStack.trayState.setActiveApplet(null)
        }
    }
}
