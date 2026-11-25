// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib

Lib.DetailPage {
    id: page
    property var nativeApplet: null
    readonly property var manager: BluezQt.Manager
    readonly property bool operational: manager.bluetoothOperational
    readonly property bool available: manager.bluetoothBlocked || manager.adapters.length > 0
    readonly property var addAction: nativeApplet ? nativeApplet.addDeviceAction : null
    readonly property var pairedDevices: {
        const result = [];
        if (operational) {
            for (const device of manager.devices)
                if (device && !device.blocked && device.paired) result.push(device);
        }
        return result;
    }

    title: i18n("Bluetooth")
    showSwitch: true
    switchEnabled: available
    switchChecked: operational
    emptyText: !available ? i18n("No Bluetooth adapters available")
        : !operational ? i18n("Bluetooth is off") : i18n("No devices paired")

    onSwitchToggled: {
        if (!available) return;
        const enable = !operational;
        manager.bluetoothBlocked = !enable;
        for (const adapter of manager.adapters) adapter.powered = enable;
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("More Bluetooth settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
    }

    listView.model: pairedDevices
    listView.spacing: 2
    listView.header: Item {
        width: page.listView.width
        height: visible ? 44 : 0
        visible: page.operational && page.addAction && page.addAction.visible && page.addAction.enabled
        PlasmaComponents3.Button {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 20
            height: 32
            icon.name: "list-add-symbolic"
            icon.width: 16
            icon.height: 16
            text: i18n("Add device")
            onClicked: page.addAction.trigger()
        }
    }

    listView.delegate: Item {
        id: row
        required property var modelData
        readonly property var device: modelData
        property var pendingCall: null
        property string lastError: ""
        width: Math.max(1, page.listView.width - 16)
        height: lastError.length > 0 ? 78 : 56
        function complete(call) {
            if (call && call.error) lastError = call.errorText || i18n("Connection failed");
            pendingCall = null;
        }
        function toggleDevice() {
            if (!device || pendingCall || !page.operational) return;
            lastError = "";
            pendingCall = device.connected ? device.disconnectFromDevice() : device.connectToDevice();
            if (pendingCall && pendingCall.isFinished) complete(pendingCall);
        }
        Connections {
            target: row.pendingCall
            function onFinished(call) { row.complete(call); }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            radius: 5
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, rowHover.hovered ? 0.07 : row.device.connected ? 0.045 : 0)
        }
        HoverHandler { id: rowHover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 10
            spacing: 12

            Kirigami.Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                source: row.device.icon || "network-bluetooth-symbolic"
                roundToIconSize: false
                isMask: true
                color: Kirigami.Theme.textColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: row.device.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 13
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: row.lastError.length ? row.lastError
                        : row.pendingCall ? (row.device.connected ? i18n("Disconnecting") : i18n("Connecting"))
                        : row.device.connected ? i18n("Connected") : i18n("Paired")
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 30
                text: row.device.connected ? i18n("Disconnect") : i18n("Connect")
                enabled: page.operational && !row.pendingCall
                onClicked: row.toggleDevice()
            }
        }
    }
}
