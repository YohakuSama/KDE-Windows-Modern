import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib
import "../js/colorType.js" as ColorType

Lib.DetailPage {
    id: page

    title: wifiAvailable ? i18n("Wi-Fi") : i18n("Network")
    showSwitch: wifiAvailable
    switchEnabled: wifiAdministrativelyEnabled
    switchChecked: page.wifiOn
    emptyText: !page.wifiAvailable ? i18n("No network connection")
        : page.wifiOn ? i18n("No available networks") : i18n("Wi-Fi is off")

    footer: Lib.MoreSettingsLink {
        text: page.wifiAvailable ? i18n("More Wi-Fi settings") : i18n("Network settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
    }

    PlasmaNM.Handler { id: handler }
    PlasmaNM.NetworkStatus { id: netStatus }
    PlasmaNM.AvailableDevices { id: availableDevices }
    PlasmaNM.EnabledConnections { id: enabledConnections }

    PlasmaNM.AppletProxyModel {
        id: appletProxyModel
        sourceModel: PlasmaNM.NetworkModel {}
    }

    readonly property bool wifiAvailable: availableDevices.wirelessDeviceAvailable
    readonly property bool wifiAdministrativelyEnabled: wifiAvailable
        && enabledConnections.wirelessHwEnabled && !PlasmaNM.Configuration.airplaneModeEnabled
    readonly property bool wifiOn: wifiAvailable && enabledConnections.wirelessHwEnabled
        && enabledConnections.wirelessEnabled

    onSwitchToggled: {
        if (wifiAdministrativelyEnabled) {
            handler.enableWireless(!wifiOn);
        }
    }

    Lib.NetworkSelection { id: selection }
    onWifiOnChanged: selection.reset()
    onVisibleChanged: if (!visible) selection.reset()

    Timer {
        interval: 10200
        repeat: true
        triggeredOnStart: true
        running: page.wifiOn && page.visible
        onTriggered: handler.requestScan()
    }

    listView.model: appletProxyModel
    listView.spacing: 2

    listView.delegate: Item {
        id: delegate
        // Balanced gutters; the scrollbar overlays the edge.
        x: 8
        width: Math.max(1, listView.width - 16)
        height: container.height + 2

        readonly property bool predictableWirelessPassword: !Uuid && Type === PlasmaNM.Enums.Wireless &&
            (SecurityType === PlasmaNM.Enums.StaticWep ||
             SecurityType === PlasmaNM.Enums.WpaPsk ||
             SecurityType === PlasmaNM.Enums.Wpa2Psk ||
             SecurityType === PlasmaNM.Enums.SAE)

        readonly property string networkKey: String(DevicePath || "") + "|" + String(ItemUniqueName || "")
        property int connectionState: ConnectionState
        readonly property bool expanded: selection.expandedKey === networkKey
        Component.onCompleted: if (connectionState === PlasmaNM.Enums.Activated)
            selection.offerConnected(networkKey)
        Component.onDestruction: selection.forget(networkKey)
        onExpandedChanged: if (!expanded) clearPassword()
        property string phase: "idle"
        property string password: ""
        property bool showPassword: false

        readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
        readonly property color subtleBg: ColorType.rowFill(dark, true, false, false)
        readonly property color hoverBg: ColorType.rowFill(dark, false, true, false)

        function statusText() {
            if (connectionState === PlasmaNM.Enums.Activated) {
                if (Type !== PlasmaNM.Enums.Wireless) return i18n("Connected");
                return SecurityType === PlasmaNM.Enums.NoneSecurity ? i18n("Connected, open") : i18n("Connected, secured");
            }
            if (connectionState === PlasmaNM.Enums.Activating) {
                return i18n("Verifying and connecting");
            }
            if (phase === "password") {
                return i18n("Enter the network security key");
            }
            return "";
        }

        function clearPassword() {
            phase = "idle";
            password = "";
            showPassword = false;
        }

        function toggleExpand() {
            selection.toggle(networkKey);
        }

        function doConnect() {
            if (predictableWirelessPassword) {
                phase = "password";
                Qt.callLater(() => {
                    if (delegate.expanded && delegate.phase === "password")
                        pwField.forceActiveFocus();
                });
            } else if (!predictableWirelessPassword && !Uuid) {
                handler.addAndActivateConnection(DevicePath, SpecificPath);
            } else {
                handler.activateConnection(ConnectionPath, DevicePath, SpecificPath);
            }
        }

        function doNext() {
            if (!expanded || phase !== "password" || !pwField.acceptableInput)
                return;
            handler.addAndActivateConnection(DevicePath, SpecificPath, password);
            clearPassword();
        }

        function doDisconnect() {
            handler.deactivateConnection(ConnectionPath, DevicePath);
            if (expanded) selection.toggle(networkKey);
        }

        onConnectionStateChanged: {
            if (connectionState === PlasmaNM.Enums.Activated) {
                clearPassword();
                selection.offerConnected(networkKey);
            }
        }

        Rectangle {
            id: container
            anchors.left: parent.left
            anchors.right: parent.right
            height: contentLayout.implicitHeight
            radius: 4
            color: delegate.expanded ? delegate.subtleBg
                 : (headerMA.containsMouse ? delegate.hoverBg : "transparent")
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

            ColumnLayout {
                id: contentLayout
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: delegate.statusText().length > 0 ? 48 : 38

                    MouseArea {
                        id: headerMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: model.ItemUniqueName
                        Accessible.onPressAction: delegate.toggleExpand()
                        Keys.onReturnPressed: delegate.toggleExpand()
                        Keys.onEnterPressed: delegate.toggleExpand()
                        Keys.onSpacePressed: delegate.toggleExpand()
                        onClicked: delegate.toggleExpand()
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Kirigami.Icon {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            roundToIconSize: false
                            source: model.ConnectionIcon
                            color: Kirigami.Theme.textColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                text: model.ItemUniqueName
                                textFormat: Text.PlainText
                                color: Kirigami.Theme.textColor
                                font.bold: connectionState === PlasmaNM.Enums.Activated
                                elide: Text.ElideRight
                            }

                            PlasmaComponents3.Label {
                                visible: delegate.statusText().length > 0
                                text: delegate.statusText()
                                color: Kirigami.Theme.textColor
                                opacity: 0.8
                                font: Kirigami.Theme.smallFont
                            }
                        }

                        PlasmaComponents3.ToolButton {
                            visible: connectionState === PlasmaNM.Enums.Activated
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            text: i18n("Network properties")
                            display: PlasmaComponents3.AbstractButton.IconOnly
                            contentItem: Kirigami.Icon {
                                source: "document-properties"
                                width: 18
                                height: 18
                                color: Kirigami.Theme.textColor
                                isMask: true
                            }
                            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
                            PlasmaComponents3.ToolTip { text: parent.text }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: delegate.expanded ? expandedCol.implicitHeight : 0
                    clip: true
                    enabled: delegate.expanded
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuad } }

                    ColumnLayout {
                        id: expandedCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 0

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }

                        // Idle: Connect button
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            visible: delegate.expanded && delegate.phase === "idle"
                                    && connectionState !== PlasmaNM.Enums.Activated
                                    && connectionState !== PlasmaNM.Enums.Activating

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30

                                PlasmaComponents3.Button {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(90, implicitWidth)
                                    height: 30
                                    text: i18n("Connect")
                                    onClicked: delegate.doConnect()
                                }
                            }
                        }

                        // Password phase
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: delegate.expanded && delegate.phase === "password"

                            PlasmaComponents3.Label {
                                text: i18n("Enter the network security key")
                                color: Kirigami.Theme.textColor
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                            }

                            TextField {
                                id: pwField
                                Layout.fillWidth: true
                                echoMode: delegate.showPassword ? TextInput.Normal : TextInput.Password
                                rightPadding: 34
                                text: delegate.password
                                onTextEdited: delegate.password = text
                                font: Kirigami.Theme.defaultFont
                                placeholderText: i18n("Password")
                                validator: RegularExpressionValidator {
                                    regularExpression: SecurityType === PlasmaNM.Enums.StaticWep
                                        ? /^(?:.{5}|[0-9a-fA-F]{10}|.{13}|[0-9a-fA-F]{26}){1}$/
                                        : SecurityType === PlasmaNM.Enums.SAE
                                            ? /^.{8,63}$/
                                            : /^(?:.{8,63}|[0-9a-fA-F]{64})$/
                                }
                                onAccepted: if (acceptableInput) delegate.doNext()

                                PlasmaComponents3.ToolButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30
                                    height: 30
                                    text: delegate.showPassword ? i18n("Hide password") : i18n("Show password")
                                    display: PlasmaComponents3.AbstractButton.IconOnly
                                    icon.name: delegate.showPassword ? "view-visible" : "view-hidden"
                                    icon.width: 16
                                    icon.height: 16
                                    onClicked: delegate.showPassword = !delegate.showPassword
                                    PlasmaComponents3.ToolTip { text: parent.text }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item { Layout.fillWidth: true }

                                PlasmaComponents3.Button {
                                    Layout.preferredWidth: Math.max(80, implicitWidth)
                                    Layout.preferredHeight: 30
                                    text: i18n("Cancel")
                                    onClicked: delegate.clearPassword()
                                }

                                PlasmaComponents3.Button {
                                    Layout.preferredWidth: Math.max(80, implicitWidth)
                                    Layout.preferredHeight: 30
                                    text: i18n("Next")
                                    enabled: pwField.acceptableInput
                                    onClicked: delegate.doNext()
                                }
                            }
                        }

                        // Connecting phase
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: delegate.expanded && connectionState === PlasmaNM.Enums.Activating

                            PlasmaComponents3.Label {
                                text: i18n("Verifying and connecting")
                                color: Kirigami.Theme.textColor
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                            }

                            PlasmaComponents3.ProgressBar {
                                Layout.fillWidth: true
                                indeterminate: true
                            }
                        }

                        // Connected phase
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            visible: delegate.expanded && connectionState === PlasmaNM.Enums.Activated

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30

                                PlasmaComponents3.Button {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(100, implicitWidth)
                                    height: 30
                                    text: i18n("Disconnect")
                                    onClicked: delegate.doDisconnect()
                                }
                            }
                        }

                        Item { Layout.fillWidth: true; Layout.preferredHeight: 8 }
                    }
                }
            }
        }
    }
}
