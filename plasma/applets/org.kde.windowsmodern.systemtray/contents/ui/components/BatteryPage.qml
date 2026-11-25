import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.kirigami as Kirigami
import org.kde.kcmutils
import org.kde.plasma.plasmoid
import "../lib" as Lib
import "../js/funcs.js" as Funcs

Lib.Page {
    id: page

    title: i18n("Battery")

    BatteryControlModel {
        id: batteryControl
    }

    PowerProfilesControl {
        id: powerProfiles
    }

    readonly property bool hasBattery: batteryControl.hasCumulative
    readonly property bool percentKnown: hasBattery && Number.isFinite(batteryControl.percent) && batteryControl.percent >= 0
    readonly property string percent: percentKnown ? i18n("%1%", batteryControl.percent) : i18n("Unknown")
    readonly property bool isCharging: batteryControl.state === BatteryControlModel.Charging
    readonly property bool isFull: batteryControl.state === BatteryControlModel.FullyCharged
    readonly property string batteryStatus: !hasBattery ? i18n("No battery")
        : isFull ? i18n("Fully charged")
        : isCharging ? i18n("Charging")
        : batteryControl.state === BatteryControlModel.Discharging ? i18n("Discharging")
        : batteryControl.pluggedIn ? i18n("Plugged in") : i18n("Battery status unknown")

    property string timeLeft: ""
    property string health: "--"
    readonly property bool blockSleep: inhibitionControl.isManuallyInhibited

    InhibitionControl {
        id: inhibitionControl
        isSilent: true
    }

    Plasma5Support.DataSource {
        id: healthSrc
        engine: "executable"
        connectedSources: []
        interval: 60000
        onNewData: function (sourceName, data) {
            var output = (data["stdout"] || "").trim();
            var h = parseFloat(output);
            if (!isNaN(h))
                page.health = (h > 100 ? 100 : h).toFixed(0) + "%";
        }
        function get(cmd) {
            connectSource(cmd);
        }
    }

    Component.onCompleted: {
        page._updateTime();
        healthSrc.get("upower -i $(upower -e | grep battery | head -n 1) | awk '/capacity/ {print $2}' | tr -d ' %' | tr ',' '.'");
    }

    function _updateTime() {
        const remaining = batteryControl.remainingMsec;
        if (remaining && remaining > 0) {
            const h = Math.floor(remaining / 3600000);
            const m = Math.floor((remaining % 3600000) / 60000);
            page.timeLeft = h + "h " + m + "m";
        } else {
            page.timeLeft = "";
        }
    }

    function _toggleBlockSleep() {
        if (inhibitionControl.isManuallyInhibited)
            inhibitionControl.uninhibit();
        else
            inhibitionControl.inhibit(i18n("Automatic sleep and screen locking disabled by user"));
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        PlasmaComponents3.Label {
            text: page.batteryStatus
            font.pixelSize: 10
            opacity: 0.6
            color: Kirigami.Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            BatteryGlyph {
                glyphSize: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                percent: page.percentKnown ? batteryControl.percent : -1
                charging: batteryControl.pluggedIn && (page.isCharging || page.isFull)
                saver: powerProfiles.activeProfile === "power-saver"
            }

            PlasmaComponents3.Label {
                text: page.percent
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Kirigami.Theme.textColor
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                visible: page.timeLeft.length > 0 && !page.isFull
                text: page.timeLeft
                font.pixelSize: 10
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }
        }

        PlasmaComponents3.ProgressBar {
            visible: page.percentKnown
            Layout.fillWidth: true
            from: 0
            to: 100
            value: batteryControl.percent
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.health !== "--"

            PlasmaComponents3.Label {
                text: i18n("Battery health")
                font.pixelSize: 9
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents3.Label {
                text: page.health
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: {
                    var h = parseFloat(page.health);
                    if (isNaN(h))
                        return Kirigami.Theme.textColor;
                    if (h >= 90)
                        return "#4ade80";
                    if (h >= 70)
                        return "#a3e635";
                    if (h >= 50)
                        return "#facc15";
                    return "#f87171";
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            height: 1
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.hasBattery

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Show battery percentage")
                wrapMode: Text.WordWrap
            }

            PlasmaComponents3.Switch {
                text: ""
                Accessible.name: i18n("Show battery percentage")
                checked: Plasmoid.configuration.showBatteryPercentage
                onClicked: Plasmoid.configuration.showBatteryPercentage = checked
            }
        }

        Lib.SectionHeader {
            text: i18n("Power Profiles")
        }

        Repeater {
            model: powerProfiles.profiles

            delegate: Lib.ListRow {
                Layout.fillWidth: true
                text: {
                    switch (modelData) {
                    case "performance":
                        return i18n("Performance");
                    case "balanced":
                        return i18n("Balanced");
                    case "power-saver":
                        return i18n("Power Saver");
                    default:
                        return modelData;
                    }
                }
                iconSource: {
                    switch (modelData) {
                    case "performance":
                        return "emblem-favorite";
                    case "balanced":
                        return "emblem-ok";
                    case "power-saver":
                        return "battery-profile-powersave-symbolic";
                    default:
                        return "";
                    }
                }
                selected: powerProfiles.activeProfile === modelData
                onClicked: powerProfiles.setProfile(modelData)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            height: 1
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Kirigami.Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: page.blockSleep ? "system-suspend-inhibited" : "system-suspend-uninhibited"
            }

            PlasmaComponents3.Label {
                text: i18n("Block sleep & screen lock")
                font.pixelSize: 12
                color: Kirigami.Theme.textColor
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents3.Switch {
                checked: page.blockSleep
                onClicked: page._toggleBlockSleep()
            }
        }
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("Power settings")
        onClicked: Qt.openUrlExternally("systemsettings://kcm_powerdevilprofilesconfig")
    }
}
