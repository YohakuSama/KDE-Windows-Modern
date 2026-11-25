// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.kcmutils
import "../lib" as Lib

// Pairing and advanced device management remain native Bluedevil actions.
Lib.Page {
    id: page

    property var nativeApplet: null
    readonly property var manager: BluezQt.Manager
    readonly property bool available: manager.bluetoothBlocked || manager.adapters.length > 0
    readonly property bool radioOn: manager.bluetoothOperational
    readonly property var devices: {
        const result = [];
        for (const device of manager.devices) {
            if (device && !device.blocked && (device.paired || device.connected))
                result.push(device);
        }
        return result;
    }
    property var pendingCall: null
    property string pendingUbi: ""
    property string failedUbi: ""
    property bool disconnecting: false

    title: i18n("Bluetooth")
    showSwitch: true
    switchEnabled: available
    switchChecked: radioOn
    contentFillsHeight: false

    onSwitchToggled: {
        if (!available)
            return;
        const enable = !radioOn;
        manager.bluetoothBlocked = !enable;
        for (const adapter of manager.adapters)
            adapter.powered = enable;
    }

    function toggleDevice(device) {
        if (!radioOn || !device || pendingCall || !device.adapter.powered)
            return;
        failedUbi = "";
        pendingUbi = device.ubi;
        disconnecting = device.connected;
        const call = disconnecting ? device.disconnectFromDevice() : device.connectToDevice();
        if (!call) {
            failedUbi = pendingUbi;
            pendingUbi = "";
            return;
        }
        pendingCall = call;
        if (call.isFinished)
            finishCall(call);
    }

    function finishCall(call) {
        if (call.error !== 0)
            failedUbi = pendingUbi;
        pendingUbi = "";
        pendingCall = null;
    }

    Connections {
        target: page.pendingCall
        function onFinished(call) { page.finishCall(call); }
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("More Bluetooth settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
    }

    Text {
        Layout.fillWidth: true
        Layout.margins: 16
        visible: !page.radioOn || page.devices.length === 0
        text: !page.available ? i18n("No Bluetooth adapter available")
            : !page.radioOn ? i18n("Bluetooth is off") : i18n("No devices paired")
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.defaultFont
        opacity: 0.8
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Lib.SectionHeader {
        visible: page.radioOn && page.devices.length > 0
        text: i18n("Bluetooth devices")
    }

    Repeater {
        model: page.radioOn ? page.devices : []
        delegate: Rectangle {
            id: deviceRow
            required property var modelData
            readonly property var device: modelData
            readonly property bool busy: page.pendingCall !== null && page.pendingUbi === device.ubi
            readonly property bool failed: page.failedUbi === device.ubi
            Lib.Win11Palette { id: fluent }
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.preferredHeight: Math.max(52, deviceLayout.implicitHeight + 12)
            radius: fluent.controlRadius
            color: device.connected ? fluent.selectionFill : pointer.hovered ? fluent.controlHover : "transparent"

            HoverHandler { id: pointer }

            RowLayout {
                id: deviceLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                Kirigami.Icon {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: deviceRow.device.icon || "network-bluetooth-symbolic"
                    roundToIconSize: false
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: deviceRow.device.friendlyName || deviceRow.device.name
                        color: fluent.text
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        Layout.fillWidth: true
                        text: deviceRow.busy ? (page.disconnecting ? i18n("Disconnecting") : i18n("Connecting"))
                            : deviceRow.failed ? i18n("Connection failed")
                            : deviceRow.device.connected ? i18n("Connected") : i18n("Not connected")
                        color: fluent.textSecondary
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                    }
                }
                Lib.FluentButton {
                    enabled: page.pendingCall === null && deviceRow.device.adapter.powered
                    text: deviceRow.device.connected ? i18n("Disconnect") : i18n("Connect")
                    onClicked: page.toggleDevice(deviceRow.device)
                }
            }
        }
    }

    Lib.FluentButton {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        visible: page.radioOn && !!page.nativeApplet?.addDeviceAction
        enabled: page.pendingCall === null && !!page.nativeApplet?.addDeviceAction?.enabled
        text: i18n("Add new device")
        onClicked: page.nativeApplet.addDeviceAction.trigger()
    }
}
