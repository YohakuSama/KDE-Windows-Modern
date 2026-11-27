// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.bluetooth as PlasmaBt
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib
import "../js/controlMetrics.js" as ControlMetrics
import "../js/colorType.js" as ColorType

Lib.DetailPage {
    id: page
    title: i18n("Bluetooth")
    readonly property bool radioAvailable: BluezQt.Manager.bluetoothBlocked || BluezQt.Manager.adapters.length > 0
    readonly property bool radioOn: BluezQt.Manager.bluetoothOperational
    showSwitch: radioAvailable
    switchEnabled: radioAvailable
    switchChecked: radioOn
    emptyText: !radioAvailable ? i18n("No Bluetooth adapters available")
        : radioOn ? i18n("No devices paired") : i18n("Bluetooth is off")

    onSwitchToggled: {
        if (!radioAvailable) return;
        const enable = !radioOn;
        BluezQt.Manager.bluetoothBlocked = !enable;
        for (const adapter of BluezQt.Manager.adapters)
            adapter.powered = enable;
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("More Bluetooth settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
    }

    PlasmaBt.DevicesProxyModel {
        id: devices
        hideBlockedDevices: true
        sourceModel: PlasmaBt.SharedDevicesStateProxyModel
    }

    listView.model: radioOn ? devices : null
    listView.spacing: 2
    listView.header: Item {
        width: page.listView.width
        height: page.radioOn ? 44 : 0
        visible: page.radioOn
        PlasmaComponents3.Button {
            id: addDevice
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: i18n("Add device")
            icon.source: addDeviceContent.nativeSource
            contentItem: NativeButtonContent {
                id: addDeviceContent
                button: addDevice
                roleName: "list-add-symbolic"
            }
            onClicked: PlasmaBt.LaunchApp.launchWizard()
        }
    }

    listView.section.property: "Section"
    listView.section.delegate: Item {
        required property string section
        width: page.listView.width
        height: 30
        PlasmaComponents3.Label {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: parent.section
            font.weight: Font.DemiBold
            opacity: 0.8
        }
    }

    listView.delegate: Item {
        id: deviceRow
        required property var model
        readonly property bool busy: model.Connecting || model.Disconnecting
        readonly property color fg: Kirigami.Theme.textColor
        width: page.listView.width
        height: 52

        Rectangle {
            id: deviceSurface
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: ControlMetrics.controlCornerRadius
            color: ColorType.rowFill(ColorType.isDark(Kirigami.Theme.backgroundColor),
                deviceRow.model.Connected, deviceHover.hovered, false)
            HoverHandler { id: deviceHover }
        }

        RowLayout {
            anchors.fill: deviceSurface
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                NativeGlyph {
                    anchors.fill: parent
                    roleName: deviceRow.model.Icon || ""
                    fallbackRoleName: "network-bluetooth-symbolic"
                    foreground: deviceRow.fg
                    isMask: nativeSource.endsWith("-symbolic.svg")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: deviceRow.model.DeviceFullName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: deviceRow.model.Connecting ? i18n("Connecting")
                        : deviceRow.model.Disconnecting ? i18n("Disconnecting")
                        : deviceRow.model.ConnectionFailed ? i18n("Connection failed")
                        : deviceRow.model.Connected ? i18n("Connected")
                        : i18n("Not connected")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }

            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 30
                visible: !!deviceRow.model.Device
                enabled: !deviceRow.busy
                text: deviceRow.model.Connected ? i18n("Disconnect") : i18n("Connect")
                onClicked: {
                    if (deviceRow.busy || !deviceRow.model.Device) return;
                    if (deviceRow.model.Connected) {
                        const call = deviceRow.model.Device.disconnectFromDevice();
                        PlasmaBt.SharedDevicesStateProxyModel.registerDisconnectingCallForDeviceUbi(call, deviceRow.model.Ubi);
                    } else {
                        const call = deviceRow.model.Device.connectToDevice();
                        PlasmaBt.SharedDevicesStateProxyModel.registerConnectingCallForDeviceUbi(call, deviceRow.model.Ubi);
                    }
                }
            }
        }
    }
}
