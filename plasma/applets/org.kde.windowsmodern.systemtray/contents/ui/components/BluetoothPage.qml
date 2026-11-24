import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib

Lib.DetailPage {
    id: page

    title: i18n("Bluetooth")
    showSwitch: btManager.adapters.length > 0
    switchChecked: page.btOn
    emptyText: btManager.adapters.length === 0 ? i18n("No Bluetooth adapter available")
        : page.btOn ? i18n("No devices paired") : i18n("Bluetooth is off")

    footer: Lib.MoreSettingsLink {
        text: i18n("More Bluetooth settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_bluetooth")
    }

    readonly property QtObject btManager: BluezQt.Manager
    readonly property bool btOn: btManager.bluetoothOperational

    function toggleBluetooth() {
        var enable = !btManager.bluetoothOperational;
        btManager.bluetoothBlocked = !enable;
        for (var i = 0; i < btManager.adapters.length; ++i) {
            btManager.adapters[i].powered = enable;
        }
    }

    onSwitchToggled: page.toggleBluetooth()

    listView.header: PlasmaComponents3.Button {
        width: listView.width
        height: page.btOn ? Math.max(32, Kirigami.Units.gridUnit * 2) : 0
        text: i18n("Add new device")
        icon.name: "list-add"
        flat: true
        visible: page.btOn

        onClicked: bluetoothExec.exec("bluedevil-wizard")
    }

    Plasma5Support.DataSource {
        id: bluetoothExec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }

    listView.model: page.btOn ? btManager.devices : []
    listView.delegate: Item {
        width: listView.width
        height: Math.max(40, Kirigami.Units.gridUnit * 2)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 4
            color: ma.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08) : "transparent"

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function activateDevice() {
                    if (!page.btOn) return;
                    if (modelData.connected)
                        modelData.disconnectFromDevice();
                    else
                        modelData.connectToDevice();
                }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name
                Accessible.description: modelData.connected ? i18n("Connected") : i18n("Disconnected")
                Accessible.onPressAction: activateDevice()
                Keys.onReturnPressed: activateDevice()
                Keys.onEnterPressed: activateDevice()
                Keys.onSpacePressed: activateDevice()
                onClicked: activateDevice()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Kirigami.Icon {
                    width: 20
                    height: 20
                    source: modelData.icon || "bluetooth"
                    color: Kirigami.Theme.textColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Kirigami.Theme.textColor
                        font: Kirigami.Theme.defaultFont
                        elide: Text.ElideRight
                    }

                    PlasmaComponents3.Label {
                        text: modelData.connected ? i18n("Connected") : i18n("Disconnected")
                        color: Kirigami.Theme.textColor
                        opacity: 0.8
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }
}
