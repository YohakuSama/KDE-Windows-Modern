import QtQuick
import QtCore
import org.kde.plasma.private.battery
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/funcs.js" as Funcs

Item {
    id: root

    property alias hasBattery: batteryControl.hasCumulative
    property alias percent: batteryControl.percent
    property alias pluggedIn: batteryControl.pluggedIn
    readonly property bool percentKnown: Number.isFinite(percent) && percent >= 0

    implicitWidth: row.implicitWidth
    implicitHeight: 16

    BatteryControlModel {
        id: batteryControl
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 3

        Kirigami.Icon {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            roundToIconSize: false
            source: {
                const name = Funcs.batteryIconName(batteryControl.percent, batteryControl.pluggedIn);
                const exact = StandardPaths.locate(StandardPaths.GenericDataLocation,
                    "icons/windows-modern/status/" + name + ".svg", StandardPaths.LocateFile);
                if (String(exact).length > 0)
                    return exact;
                const fallback = StandardPaths.locate(StandardPaths.GenericDataLocation,
                    "icons/windows-modern/status/" + name.replace(/-symbolic$/, "") + ".svg", StandardPaths.LocateFile);
                return String(fallback).length > 0 ? fallback : name;
            }
            color: Kirigami.Theme.textColor
            isMask: true
        }

        PlasmaComponents3.Label {
            visible: root.hasBattery && root.percentKnown
            text: i18n("%1%", batteryControl.percent)
            color: Kirigami.Theme.textColor
            opacity: 0.9
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
