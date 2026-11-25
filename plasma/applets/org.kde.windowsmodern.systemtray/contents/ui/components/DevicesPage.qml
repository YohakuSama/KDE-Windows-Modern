// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../lib" as Lib

// Reuse the model of the already-loaded native device notifier. Never
// instantiate a second monitor or execute mount/eject commands ourselves.
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

    Text {
        Layout.fillWidth: true
        Layout.margins: 16
        visible: devices.count === 0
        text: i18n("No removable devices attached")
        textFormat: Text.PlainText
        font: Kirigami.Theme.defaultFont
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
            // Plasma StateInfo::NotPresent is 0. A removed row can stay
            // in the model briefly to display the operation result.
            present: deviceState !== 0
            message: deviceMessage
            actions: deviceActions
        }
    }
}
