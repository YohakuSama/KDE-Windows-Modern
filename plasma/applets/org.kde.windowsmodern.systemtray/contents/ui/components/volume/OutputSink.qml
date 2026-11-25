// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.private.volume as Vol

QtObject {
    id: root

    readonly property var devices: Vol.SinkModel {}
    readonly property var preferredSink: Vol.PreferredDevice.sink
    readonly property bool preferredAvailable: usable(preferredSink)
    property var fallbackSink: null
    readonly property var sink: preferredAvailable ? preferredSink : fallbackSink
    readonly property bool available: usable(sink)

    function usable(device) {
        return !!device && device.name !== "auto_null";
    }

    // Plasma versions before the PreferredDevice initialization fix can
    // report null even when a default output already exists. Only fall
    // back to the actual default output; never choose an arbitrary device.
    function refreshDefault() {
        if (preferredAvailable || !devices) {
            fallbackSink = null;
            return;
        }
        const role = devices.role("PulseObject");
        if (role < 0) {
            fallbackSink = null;
            return;
        }
        for (let i = 0; i < devices.count; ++i) {
            const device = devices.data(devices.index(i, 0), role);
            if (usable(device) && device.default) {
                fallbackSink = device;
                return;
            }
        }
        fallbackSink = null;
    }

    onPreferredAvailableChanged: refreshDefault()
    Component.onCompleted: refreshDefault()

    readonly property var deviceConnections: Connections {
        target: root.devices
        function onRowsInserted() { root.refreshDefault(); }
        function onRowsRemoved() { root.refreshDefault(); }
        function onModelReset() { root.refreshDefault(); }
        function onDataChanged(topLeft, bottomRight, roles) {
            if (!root.preferredAvailable
                && (!roles || roles.length === 0
                    || roles.indexOf(root.devices.role("Default")) !== -1
                    || roles.indexOf(root.devices.role("Name")) !== -1
                    || roles.indexOf(root.devices.role("PulseObject")) !== -1)) {
                root.refreshDefault();
            }
        }
    }
}
