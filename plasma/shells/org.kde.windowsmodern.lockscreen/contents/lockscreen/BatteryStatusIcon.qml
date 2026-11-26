// Live battery icon. Share the original Windows shell artwork and level
// selection with the panel; hide the existing control on batteryless PCs.
// The Loader still isolates a missing battery backend.
import QtQuick
import org.kde.plasma.private.battery
import "batteryState.js" as BatteryState

StatusIconButton {
    id: statusButton

    BatteryControlModel {
        id: battery
    }
    readonly property bool available: battery.hasCumulative
    readonly property real displayPercent: BatteryState.boundedBatteryPercent(battery.percent)
    readonly property bool percentKnown: available && displayPercent >= 0
    readonly property bool charging: battery.pluggedIn && battery.state === BatteryControlModel.Charging
    visible: available
    icon.name: ""
    contentItem: Item {
        BatteryGlyph {
            anchors.centerIn: parent
            glyphSize: Math.max(0, Math.min(16, parent.height, Math.floor(parent.width) / 1.25))
            width: implicitWidth
            height: implicitHeight
            percent: statusButton.percentKnown ? statusButton.displayPercent : -1
            charging: statusButton.charging
            pluggedIn: battery.pluggedIn
            foreground: "#FFFFFF"
        }
    }
    text: !percentKnown
        ? i18nd("plasma_shell_org.kde.plasma.desktop", "Battery level unknown")
        : charging
            ? i18nd("plasma_shell_org.kde.plasma.desktop", "Battery: %1% (charging)", Math.round(displayPercent))
            : i18nd("plasma_shell_org.kde.plasma.desktop", "Battery: %1%", Math.round(displayPercent))
}
