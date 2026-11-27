import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.kitemmodels as KItemModels
import "../lib" as Lib
import "../js/funcs.js" as Funcs

Lib.Slider {
    id: root

    property var mainScreen: null
    property rect panelScreenGeometry: Qt.rect(0, 0, 0, 0)
    property int panelScreenIndex: -1

    sliderAccessibleName: brightnessAvailable ? i18n("Brightness") : i18n("Select a display in brightness details")
    detailsAccessibleName: i18n("Display brightness details")
    iconSource: "brightness-high-symbolic"
    iconSize: 20
    showArrow: true

    ScreenBrightnessControl {
        id: sbControl
        isSilent: false
    }

    // The brightness backend exposes only opaque DBus names ("display3",
    // "display4") as displayName, so we cannot match by KScreen connector
    // name. Instead we decide whether the panel sits on an internal or
    // external screen and pick the corresponding display.
    function displayForPanel() {
        const model = sbControl.displays;
        if (!model || model.rowCount() === 0) {
            return null;
        }
        const isInternalRole = model.KItemModels.KRoleNames.role("isInternal");
        const flags = [];
        for (let i = 0; i < model.rowCount(); ++i)
            flags.push(model.data(model.index(i, 0), isInternalRole));
        const chosen = Funcs.brightnessDisplayIndex(flags, root.panelOnInternalScreen());
        return chosen >= 0 ? model.index(chosen, 0) : null;
    }

    // True for an internal panel, false for an external connector, null
    // if neither screen lookup yields a connector name.
    //
    // Qt.application.screens[i].geometry is not exposed to QML in current
    // Qt/Plasma builds (only .name is), so geometry matching is impossible.
    // We resolve the connector name via the containment's screen index, and
    // fall back to the Screen attached property (the popup window's screen,
    // which opens on the panel's screen). Do not guess when both are absent.
    function isInternalConnectorName(name) {
        return Funcs.isInternalConnectorName(name);
    }

    function panelOnInternalScreen() {
        const idx = root.panelScreenIndex;
        const screens = Qt.application.screens;
        if (idx >= 0 && screens && screens.length > idx) {
            const s = screens[idx];
            if (s && s.name) {
                return root.isInternalConnectorName(s.name);
            }
        }
        if (typeof Screen !== "undefined" && Screen.name) {
            return root.isInternalConnectorName(Screen.name);
        }
        return null;
    }

    function refreshDisplays() {
        const model = sbControl.displays;
        const idx = root.displayForPanel();
        if (!model || !idx) {
            root.mainScreen = null;
            return;
        }
        const labelRole = model.KItemModels.KRoleNames.role("label");
        const brightnessRole = model.KItemModels.KRoleNames.role("brightness");
        const maxBrightnessRole = model.KItemModels.KRoleNames.role("maxBrightness");
        const displayNameRole = model.KItemModels.KRoleNames.role("displayName");
        root.mainScreen = {
            displayName: model.data(idx, displayNameRole),
            label: model.data(idx, labelRole),
            brightness: model.data(idx, brightnessRole),
            maxBrightness: model.data(idx, maxBrightnessRole)
        };
    }

    Connections {
        target: sbControl.displays
        function onDataChanged() {
            root.refreshDisplays();
        }
        function onModelReset() {
            root.refreshDisplays();
        }
        function onLayoutChanged() {
            root.refreshDisplays();
        }
        function onRowsInserted() {
            root.refreshDisplays();
        }
        function onRowsRemoved() {
            root.refreshDisplays();
        }
    }

    Component.onCompleted: root.refreshDisplays()

    onPanelScreenGeometryChanged: root.refreshDisplays()
    onPanelScreenIndexChanged: root.refreshDisplays()

    readonly property bool displayControlsAvailable: sbControl.isBrightnessAvailable
    readonly property bool brightnessAvailable: displayControlsAvailable && mainScreen !== null
        && !!mainScreen.displayName && Number.isFinite(mainScreen.brightness)
        && Number.isFinite(mainScreen.maxBrightness) && mainScreen.maxBrightness > 0
    visible: displayControlsAvailable
    trackEnabled: brightnessAvailable
    // The per-display PowerDevil API already subtracts its safe minimum.
    // Zero is the normalized lower endpoint, as in Plasma's BrightnessItem.
    from: 0
    to: brightnessAvailable ? mainScreen.maxBrightness : 100
    value: brightnessAvailable ? mainScreen.brightness : 0
    stepSize: brightnessAvailable ? Math.max(1, Math.floor(mainScreen.maxBrightness / 100)) : 1

    onMoved: function (v) {
        if (brightnessAvailable) {
            sbControl.setBrightness(mainScreen.displayName, v);
        }
    }

    // The sun is a brightness label, not a second Night Light toggle.
}
