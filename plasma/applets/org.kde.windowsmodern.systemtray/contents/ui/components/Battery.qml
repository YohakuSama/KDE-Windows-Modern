// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    property alias hasBattery: batteryControl.hasCumulative
    property alias percent: batteryControl.percent
    property alias pluggedIn: batteryControl.pluggedIn
    readonly property bool percentKnown: hasBattery && Number.isFinite(percent) && percent >= 0
    readonly property bool charging: pluggedIn && (batteryControl.state === BatteryControlModel.Charging
        || batteryControl.state === BatteryControlModel.FullyCharged)

    property bool showPercentage: true
    property real glyphSize: 16
    property real labelPixelSize: 12
    property real percentageWidth: 0

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(glyphSize, row.implicitHeight)

    BatteryControlModel { id: batteryControl }
    PowerProfilesControl { id: powerProfiles }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        BatteryGlyph {
            glyphSize: root.glyphSize
            width: implicitWidth
            height: implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            percent: root.percentKnown ? root.percent : -1
            charging: root.charging
            saver: powerProfiles.activeProfile === "power-saver"
        }

        PlasmaComponents3.Label {
            visible: root.showPercentage && root.percentKnown
            text: i18n("%1%", Math.round(root.percent))
            width: Math.max(implicitWidth, root.percentageWidth)
            color: Kirigami.Theme.textColor
            font.family: Kirigami.Theme.defaultFont.family
            font.pixelSize: root.labelPixelSize
            font.features: { "tnum": 1 }
            horizontalAlignment: Text.AlignLeft
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
