/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2022 ivan tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtCore

import org.kde.kirigami as Kirigami

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.volume as Vol
import "components" as Components
import "js/funcs.js" as Funcs

AbstractItem {
    id: plasmoidContainer

    property Item applet: model?.applet ?? null
    property bool groupWasOpen: false
    text: applet?.Plasmoid.title ?? ""

    itemId: applet?.Plasmoid.pluginName ?? ""
    mainText: applet ? (applet.toolTipMainText || text) : ""
    subText: applet?.toolTipSubText ?? ""
    mainItem: applet?.toolTipItem ?? null
    textFormat: applet?.toolTipTextFormat ?? 0 /* Text.AutoText, the default value */
    active: inVisibleLayout || (!!applet && systemTrayState.activeApplet !== applet
        && (mainText.length > 0 || subText.length > 0))

    // FIXME: Use an input type agnostic way to activate whatever the primary
    // action of a plasmoid is supposed to be, even if it's just expanding the
    // Plasmoid. Not all plasmoids are supposed to expand and not all plasmoids
    // do anything with onActivated.
    onActivated: pos => {
        if (groupedQuickSettings) {
            root.quickSettingsOrigin = plasmoidContainer;
            systemTrayState.toggleHome(false);
            return;
        }
        if (applet) {
            applet.Plasmoid.activated()
        }
    }

    onClicked: mouse => {
        if (!applet) {
            return
        }
        if (groupedQuickSettings && mouse.button === Qt.LeftButton) {
            root.quickSettingsOrigin = plasmoidContainer;
            systemTrayState.toggleHome(false, groupWasOpen);
            return;
        }
        //forward click event to the applet
        const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
        const mouseArea = findMouseArea(appletItem)

        if (mouseArea && mouse.button !== Qt.RightButton) {
            mouseArea.clicked(mouse)
        } else if (mouse.button === Qt.LeftButton) {//fallback
            activated(null)
        }
    }
    onPressed: mouse => {
        if (!applet) return;
        if (groupedQuickSettings && mouse.button === Qt.LeftButton) {
            groupWasOpen = systemTrayState.quickSettingsOpen;
            return;
        }
        // Only Plasmoids can show context menu on the mouse pressed event.
        // SNI has few problems, for example legacy applications that still use XEmbed require mouse to be released.
        if (mouse.button === Qt.RightButton) {
            contextMenu(mouse);
        } else {
            const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
            const mouseArea = findMouseArea(appletItem)
            if (mouseArea) {
                // The correct way here would be to invoke the "pressed"
                // signal; however, mouseArea.pressed signal is overridden
                // by its bool value, and our only option is to call the
                // handler directly.
                mouseArea.onPressed(mouse)
            }
        }
    }
    onContextMenu: mouse => {
        if (applet) {
            effectivePressed = false;
            Plasmoid.showPlasmoidMenu(applet, 0, inHiddenLayout ? applet.height : 0);
        }
    }
    onWheel: wheel => {
        if (!applet) {
            return
        }
        //forward wheel event to the applet
        const appletItem = applet.compactRepresentationItem ?? applet.fullRepresentationItem
        const mouseArea = findMouseArea(appletItem)
        if (mouseArea) {
            mouseArea.wheel(wheel)
        }
    }

    function __isSuitableMouseArea(child: Item): bool {
        const item = child.parent;
        return child instanceof MouseArea
            && child.enabled
            // check if MouseArea covers the entire item
            && (child.anchors.fill === item
                || (child.x === 0
                    && child.y === 0
                    && child.width === item.width
                    && child.height === item.height));
    }

    //some heuristics to find MouseArea
    function findMouseArea(item: Item): MouseArea {
        if (!item) {
            return null
        }

        if (item instanceof MouseArea) {
            return item as MouseArea
        }

        return item.children.find(__isSuitableMouseArea) ?? null;
    }

    //This is to make preloading effective, minimizes the scene changes
    function preloadFullRepresentationItem(fullRepresentationItem) {
        if (fullRepresentationItem && fullRepresentationItem.parent === null) {
            fullRepresentationItem.width = expandedRepresentation.width
            fullRepresentationItem.height = expandedRepresentation.height
            fullRepresentationItem.parent = preloadedStorage;
        }
    }

    // Direct optical status glyphs use the tray's logical canvas. Native
    // applets still own presence, state, activation, tooltips and menus.
    // Device notifier must not be shrunk by the embedded applet again.
    Loader {
        id: statusGlyphLoader
        parent: plasmoidContainer.iconContainer
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        active: (plasmoidContainer.groupedQuickSettings
                && (plasmoidContainer.itemId !== "org.kde.plasma.battery" || root.panelHasBattery))
            || (plasmoidContainer.inVisibleLayout
                && (plasmoidContainer.itemId === "org.kde.plasma.devicenotifier"
                    || (plasmoidContainer.itemId === "org.kde.plasma.bluetooth"
                        && BluezQt.Manager.bluetoothOperational)))
        sourceComponent: {
            switch (plasmoidContainer.itemId) {
            case "org.kde.plasma.networkmanagement": return networkGlyph;
            case "org.kde.plasma.volume": return volumeGlyph;
            case "org.kde.plasma.battery": return batteryGlyph;
            case "org.kde.plasma.bluetooth": return bluetoothGlyph;
            case "org.kde.plasma.devicenotifier": return removableGlyph;
            default: return null;
            }
        }
    }

    function panelGlyphFile(name) {
        return StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/status/" + name + ".svg", StandardPaths.LocateFile);
    }

    function panelGlyph(name) {
        const file = panelGlyphFile(name);
        if (String(file).length > 0)
            return file;
        const fallback = panelGlyphFile(name.replace(/-symbolic$/, ""));
        return String(fallback).length > 0 ? fallback : name;
    }

    Component {
        id: networkGlyph
        Item {
            PlasmaNM.ConnectionIcon { id: liveConnection }
            Kirigami.Icon {
                anchors.fill: parent
                roundToIconSize: false
                isMask: true
                source: {
                    const icon = liveConnection.connectionIcon;
                    if (!icon) return plasmoidContainer.panelGlyph("network-unavailable-symbolic");
                    return plasmoidContainer.panelGlyph(icon.endsWith("-symbolic") ? icon : icon + "-symbolic");
                }
                color: Kirigami.Theme.textColor
            }
        }
    }

    Component {
        id: bluetoothGlyph
        Kirigami.Icon {
            roundToIconSize: false
            isMask: true
            source: plasmoidContainer.panelGlyph("network-bluetooth-symbolic")
            color: Kirigami.Theme.textColor
        }
    }

    Component {
        id: removableGlyph
        Kirigami.Icon {
            roundToIconSize: false
            isMask: true
            source: plasmoidContainer.panelGlyph("device-notifier-symbolic")
            color: Kirigami.Theme.textColor
        }
    }

    Component {
        id: volumeGlyph
        Kirigami.Icon {
            readonly property var sink: Vol.PreferredDevice.sink
            readonly property bool available: !!sink && sink.name !== "auto_null"
            roundToIconSize: false
            isMask: true
            source: plasmoidContainer.panelGlyph(Funcs.volIconName(available ? sink.volume : 0, !available || sink.muted))
            color: Kirigami.Theme.textColor
        }
    }

    Component {
        id: batteryGlyph
        Components.Battery {
            glyphSize: root.batteryGlyphSize
            showPercentage: root.showPanelBatteryPercentage
            percentageWidth: root.batteryPercentageWidth
            labelPixelSize: 12
        }
    }

    Item {
        id: nativeAppletHost
        visible: statusGlyphLoader.status !== Loader.Ready
        parent: plasmoidContainer.iconContainer
        anchors.centerIn: parent
        width: plasmoidContainer.groupedQuickSettings
            ? plasmoidContainer.coreNativeRenderSize : parent.width
        height: plasmoidContainer.groupedQuickSettings ? width : parent.height
        scale: plasmoidContainer.groupedQuickSettings && width > 0
            ? Math.min(parent.width, parent.height) / width : 1
        transformOrigin: Item.Center
    }

    onAppletChanged: {
        if (applet) {
            applet.parent = nativeAppletHost
            applet.anchors.fill = applet.parent
            applet.visible = true

            preloadFullRepresentationItem(applet.fullRepresentationItem)
        }
        Qt.callLater(fitLanguageLabel)
    }

    Connections {
        enabled: plasmoidContainer.applet !== null
        target: plasmoidContainer.findMouseArea(
            plasmoidContainer.applet?.compactRepresentationItem ??
            plasmoidContainer.applet?.fullRepresentationItem ??
            plasmoidContainer.applet
        )

        function onContainsPressChanged() {
            plasmoidContainer.effectivePressed = (target as MouseArea).containsPress;
        }

        // TODO For touch/stylus only, since the feature is not desired for mouse users
        function onPressAndHold(mouse) {
            if (mouse.button === Qt.LeftButton) {
                plasmoidContainer.contextMenu(mouse)
            }
        }
    }

    Connections {
        target: plasmoidContainer.applet?.Plasmoid ?? null

        //activation using global keyboard shortcut
        function onActivated() {
            plasmoidContainer.effectivePressed = true;
            Qt.callLater(() => {
                plasmoidContainer.effectivePressed = false;
            });
        }
    }

    Connections {
        target: plasmoidContainer.applet

        function onFullRepresentationItemChanged(fullRepresentationItem) {
            plasmoidContainer.preloadFullRepresentationItem(fullRepresentationItem)
        }

        function onExpandedChanged(expanded) {
            if (expanded) {
                plasmoidContainer.effectivePressed = false;
            }
        }
    }

    // Windows draws the input language ("ENG") at the clock's text size. The
    // stock keyboard-layout widget fits its label to the whole icon cell,
    // which on a tall panel makes it larger than the clock. Give that label
    // the normal UI font size instead. If a future Plasma changes the
    // widget's label, nothing is found and the stock size stays.
    function findFitLabel(item: Item): Item {
        if (!item) {
            return null;
        }
        if (item.fontSizeMode === Text.Fit && item.text !== undefined) {
            return item;
        }
        for (let i = 0; i < item.children.length; ++i) {
            const found = findFitLabel(item.children[i]);
            if (found) {
                return found;
            }
        }
        return null;
    }
    function fitLanguageLabel(): void {
        if (itemId !== "org.kde.plasma.keyboardlayout") {
            return;
        }
        // The widget shows its full representation in the panel directly.
        const label = findFitLabel(applet?.compactRepresentationItem ?? applet?.fullRepresentationItem ?? null);
        if (label) {
            label.fontSizeMode = Text.FixedSize;
            label.font.pointSize = Qt.binding(() => Kirigami.Theme.defaultFont.pointSize);
        }
    }
    Component.onCompleted: Qt.callLater(fitLanguageLabel)
    Connections {
        target: plasmoidContainer.applet
        function onCompactRepresentationItemChanged() {
            Qt.callLater(plasmoidContainer.fitLanguageLabel);
        }
        function onFullRepresentationItemChanged() {
            Qt.callLater(plasmoidContainer.fitLanguageLabel);
        }
    }

    PlasmaComponents3.BusyIndicator {
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: plasmoidContainer.inHiddenLayout ? Math.round(Kirigami.Units.smallSpacing / 2) : 0
            right: plasmoidContainer.inHiddenLayout ? undefined : parent.right
        }
        z: 999
        running: plasmoidContainer.applet?.Plasmoid.busy ?? false
    }

    Binding {
        property: "hideOnWindowDeactivate"
        value: !Plasmoid.configuration.pin
        target: plasmoidContainer.applet
        when: plasmoidContainer.applet !== null
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        property: "activeFocusOnTab"
        value: false
        target: plasmoidContainer.applet?.compactRepresentationItem ?? null
        when: plasmoidContainer?.applet && plasmoidContainer.inHiddenLayout
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        property: "activeFocusOnTab"
        value: false
        target: plasmoidContainer.applet?.fullRepresentationItem ?? null
        when: plasmoidContainer?.applet && plasmoidContainer.inHiddenLayout && !plasmoidContainer.applet.compactRepresentationItem
        restoreMode: Binding.RestoreBinding
    }
}
