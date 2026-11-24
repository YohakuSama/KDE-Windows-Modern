/*
    Action Panel — Windows 11 Quick Settings, separate from tray overflow.
    Existing KDE toggle/slider backends are preserved.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid

import "components" as Components

ColumnLayout {
    id: actionPanel

    signal requestPage(string name)

    readonly property real scale: Plasmoid.configuration.scale / 100

    Layout.fillWidth: true
    spacing: 16 * actionPanel.scale

    // Scroll additional rows independently of the sliders and footer.
    Flickable {
        id: toggleViewport
        Layout.fillWidth: true
        Layout.leftMargin: 14 * actionPanel.scale
        Layout.rightMargin: 14 * actionPanel.scale
        Layout.topMargin: 12 * actionPanel.scale
        Layout.preferredHeight: Math.min(toggleGrid.implicitHeight,
            2 * networkTile.implicitHeight + toggleGrid.rowSpacing)
        contentWidth: width
        contentHeight: toggleGrid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: contentHeight > height
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

        GridLayout {
            id: toggleGrid
            width: toggleViewport.width
            height: implicitHeight
            columns: 3
            rowSpacing: 12 * actionPanel.scale
            columnSpacing: 6 * actionPanel.scale
    
            Components.NetworkToggle {
                id: networkTile
                Layout.fillWidth: true
                onArrowClicked: actionPanel.requestPage("network")
            }
            Components.BluetoothToggle {
                Layout.fillWidth: true
                onArrowClicked: actionPanel.requestPage("bluetooth")
            }
            Components.AirplaneToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showAirplane
            }
            Components.BatterySaverToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showBatterySaver && available
                onArrowClicked: actionPanel.requestPage("battery")
            }
            Components.NightLightToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showNightLight
            }
            Components.ColorSchemeToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showColorScheme
            }
            Components.DndToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showDnd
            }
            Components.MicMuteToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showMicMute
            }
            Components.HotspotToggle {
                Layout.fillWidth: true
                visible: Plasmoid.configuration.showHotspot && hotspotSupported
            }
        }
    }

    GridLayout {
        visible: (Plasmoid.configuration.showBrightness && brightnessSlider.brightnessAvailable)
            || (Plasmoid.configuration.showVolume && volumeSlider.sinkAvailable)
        Layout.fillWidth: true
        Layout.leftMargin: 14 * actionPanel.scale
        Layout.rightMargin: 14 * actionPanel.scale
        Layout.bottomMargin: 14 * actionPanel.scale
        columns: 3
        rowSpacing: 12 * actionPanel.scale
        columnSpacing: 0

        Components.BrightnessSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            visible: Plasmoid.configuration.showBrightness && brightnessAvailable
            showArrow: true
            panelScreenGeometry: Plasmoid.screenGeometry
            panelScreenIndex: Plasmoid.containment.screen
            onArrowClicked: actionPanel.requestPage("brightness")
        }
        Components.VolumeSlider {
            id: volumeSlider
            Layout.fillWidth: true
            Layout.columnSpan: 3
            Layout.preferredHeight: Math.round(36 * actionPanel.scale)
            visible: Plasmoid.configuration.showVolume && sinkAvailable
            onArrowClicked: actionPanel.requestPage("volume")
        }
    }

    Components.Footer {
        Layout.fillWidth: true
        Layout.topMargin: -6 * actionPanel.scale
        uiScale: actionPanel.scale
        showBattery: Plasmoid.configuration.showBattery
        onBatteryClicked: actionPanel.requestPage("battery")
    }
}
