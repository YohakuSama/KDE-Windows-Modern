/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@koyotic.space>
    SPDX-FileCopyrightText: 2026 Jeysef

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

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

    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12

    readonly property Item activeApplet: systemTrayState.activeApplet

    // Whether the active applet is one we render a themed flyout for.
    readonly property bool themedActive: !!(themedPages && themedPages[flyoutRouter.flyoutNameForApplet(activeApplet)])

    // Height reserved at the bottom for the themed page's footer link.
    readonly property int themedFooterHeight: (themedActive && footerLoader.item) ? themedFooter.implicitHeight : 0

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

    function _themedContentHeight(): int {
        return Math.max(0, mainStack.height - mainStack.themedFooterHeight)
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
                    "height": Qt.binding(() => mainStack._themedContentHeight()),
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
        if (currentItem !== null && root.expanded) {
            currentItem.forceActiveFocus()
        }
    }

    Connections {
        target: Plasmoid
        function onAppletRemoved(applet) {
            if (applet === systemTrayState.activeApplet) {
                systemTrayState.setActiveApplet(null)
                mainStack.clear(QQC2.StackView.Immediate)
            }
        }
    }

    // Footer link for themed pages (e.g. "More Wi-Fi settings"). Lib.Page
    // declares `footer` as a Component but does not render it — we render it
    // here so the link sits at the bottom of the flyout, Win11-style.
    Rectangle {
        id: themedFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: mainStack.themedActive && footerLoader.sourceComponent !== null
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)
        implicitHeight: footerLoader.item ? footerLoader.item.implicitHeight + 8 : 0
        height: implicitHeight

        Loader {
            id: footerLoader
            anchors.fill: parent
            sourceComponent: mainStack.themedActive && mainStack.currentItem && mainStack.currentItem.footer !== undefined ? mainStack.currentItem.footer : null
        }
    }

    readonly property var themedPages: ({
        "network":         networkPageComp,
        "volume":          volumePageComp,
        "battery":         batteryPageComp,
        "brightness":      brightnessPageComp,
        "clipboard":       clipboardPageComp,
        "mediacontroller": mediaControllerPageComp
    })

    Component {
        id: networkPageComp
        Components.NetworkPage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
    Component {
        id: volumePageComp
        Components.VolumePage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
    Component {
        id: batteryPageComp
        Components.BatteryPage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
    Component {
        id: brightnessPageComp
        Components.BrightnessPage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
    Component {
        id: clipboardPageComp
        Components.ClipboardPage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
    Component {
        id: mediaControllerPageComp
        Components.MediaControllerPage {
            onBack: systemTrayState.setActiveApplet(null)
        }
    }
}
