import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.kirigami as Kirigami
import org.kde.kcmutils
import org.kde.plasma.plasmoid
import "../lib" as Lib
import "../js/colorType.js" as ColorType
import "../js/funcs.js" as Funcs

Lib.Page {
    id: page

    title: i18n("Battery")
    contentFillsHeight: false
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property color accent: ColorType.accentForSurface(Kirigami.Theme.highlightColor,
        Qt.color(ColorType.cardFill(dark, false)))

    BatteryControlModel {
        id: batteryControl
    }

    PowerProfilesControl {
        id: powerProfiles
    }

    readonly property bool hasBattery: batteryControl.hasCumulative
    readonly property real displayPercent: Funcs.boundedBatteryPercent(batteryControl.percent)
    readonly property bool percentKnown: hasBattery && displayPercent >= 0
    readonly property string percent: percentKnown ? i18n("%1%", Math.round(displayPercent)) : i18n("Unknown")
    readonly property bool isCharging: batteryControl.state === BatteryControlModel.Charging
    readonly property bool isFull: batteryControl.state === BatteryControlModel.FullyCharged
    readonly property string batteryStatus: !hasBattery ? i18n("No battery")
        : isFull ? i18n("Fully charged")
        : isCharging ? i18n("Charging")
        : batteryControl.state === BatteryControlModel.Discharging ? i18n("Discharging")
        : batteryControl.pluggedIn ? i18n("Plugged in") : i18n("Battery status unknown")

    readonly property string timeLeft: {
        const remaining = batteryControl.smoothedRemainingMsec;
        if (!hasBattery || !(remaining > 0)) return "";
        const duration = KCoreAddons.Format.formatDuration(remaining, KCoreAddons.FormatTypes.HideSeconds);
        if (isCharging) return i18n("%1 until fully charged", duration);
        if (batteryControl.state === BatteryControlModel.Discharging)
            return i18n("%1 remaining", duration);
        return "";
    }
    readonly property bool blockSleep: inhibitionControl.isManuallyInhibited

    InhibitionControl {
        id: inhibitionControl
        isSilent: true
    }

    function _toggleBlockSleep() {
        if (inhibitionControl.isManuallyInhibited)
            inhibitionControl.uninhibit();
        else
            inhibitionControl.inhibit(i18n("Automatic sleep and screen locking disabled by user"));
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 4
        Layout.bottomMargin: 8
        spacing: 10

        PlasmaComponents3.Label {
            text: page.batteryStatus
            font.pixelSize: 12
            opacity: 0.75
            color: Kirigami.Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            BatteryGlyph {
                glyphSize: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                percent: page.percentKnown ? page.displayPercent : -1
                charging: batteryControl.pluggedIn && page.isCharging
                pluggedIn: batteryControl.pluggedIn
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
                Layout.maximumWidth: Math.max(0, parent.width * 0.5)
                text: page.timeLeft
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                opacity: 0.75
                color: Kirigami.Theme.textColor
            }
        }

        Rectangle {
            visible: page.percentKnown
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: ColorType.trackFill(page.dark)
            Accessible.role: Accessible.ProgressBar
            Accessible.name: page.percent
            Rectangle {
                width: parent.width * (page.percentKnown ? Funcs.batteryFillFraction(page.displayPercent) : 0)
                height: parent.height
                radius: 2
                color: page.accent
            }
        }

        // Use KDE's live battery roles rather than a subprocess querying the
        // first UPower device, which may be a peripheral or the wrong battery.
        Repeater {
            id: healthRows
            model: batteryControl
            delegate: RowLayout {
                required property var model
                readonly property real capacity: Number(model.Capacity)
                Layout.fillWidth: true
                visible: model.IsPowerSupply && capacity > 0 && capacity <= 100

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: healthRows.count > 1 && model.PrettyName
                        ? i18n("%1 battery health", model.PrettyName) : i18n("Battery health")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    opacity: 0.75
                }
                PlasmaComponents3.Label {
                    text: i18n("%1%", Math.round(capacity))
                    font.pixelSize: 12
                    color: Kirigami.Theme.textColor
                }
            }
        }

        Rectangle {
            visible: page.hasBattery
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            height: 1
            color: ColorType.divider(page.dark)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.hasBattery

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Show battery percentage")
                wrapMode: Text.WordWrap
            }

            Lib.FluentSwitch {
                shellAccent: page.shellAccent
                Accessible.name: i18n("Show battery percentage")
                checked: Plasmoid.configuration.showBatteryPercentage
                onToggled: {
                    Plasmoid.configuration.showBatteryPercentage = checked;
                    checked = Qt.binding(() => Plasmoid.configuration.showBatteryPercentage);
                }
            }
        }

        Lib.SectionHeader {
            visible: powerProfiles.profiles.length > 0
            text: i18n("Power Profiles")
        }

        Repeater {
            model: powerProfiles.profiles

            delegate: Lib.ListRow {
                Layout.fillWidth: true
                inset: 0
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
            visible: page.hasBattery || powerProfiles.profiles.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            height: 1
            color: ColorType.divider(page.dark)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                visible: sleepGlyph.nativeSource.length > 0
                NativeGlyph {
                    id: sleepGlyph
                    anchors.fill: parent
                    roleName: page.blockSleep ? "system-suspend-inhibited" : "system-suspend-uninhibited"
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Block sleep & screen lock")
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: Kirigami.Theme.textColor
            }

            Lib.FluentSwitch {
                shellAccent: page.shellAccent
                Accessible.name: i18n("Block sleep & screen lock")
                checked: page.blockSleep
                onToggled: {
                    page._toggleBlockSleep();
                    checked = Qt.binding(() => page.blockSleep);
                }
            }
        }
    }

    footer: Lib.MoreSettingsLink {
        text: i18n("Power settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig")
    }
}
