// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../lib" as Lib

// Reuse the already-loaded native Device Notifier model. Do not start a
// second device monitor or replace KDE's mount/eject action implementation.
Lib.Page {
    id: page
    property var nativeApplet: null
    readonly property var deviceModel: nativeApplet?.fullRepresentationItem?.model ?? null

    title: i18n("Safely remove hardware")
    contentFillsHeight: false

    footer: Lib.MoreSettingsLink {
        readonly property var configureAction: page.nativeApplet?.plasmoid?.internalAction("configure") ?? null
        text: i18n("More device settings")
        enabled: configureAction !== null && configureAction.enabled
        onClicked: if (configureAction && configureAction.enabled) configureAction.trigger()
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.margins: 16
        visible: devices.count === 0
        text: i18n("No removable devices attached")
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    Repeater {
        id: devices
        model: page.deviceModel
        delegate: DeviceRow {
            required property string deviceDescription
            required property string deviceIcon
            required property bool deviceIsBusy
            required property bool deviceMounted
            required property int deviceState
            required property string deviceMessage
            required property var deviceActions

            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            description: deviceDescription
            iconName: deviceIcon
            busy: deviceIsBusy
            mounted: deviceMounted
            // Plasma StateInfo::NotPresent is 0. A removed row can remain
            // briefly so its native operation result stays visible.
            present: deviceState !== 0
            message: deviceMessage
            actions: deviceActions
        }
    }
}
