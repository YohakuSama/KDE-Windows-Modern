// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib
import "volume" as Volume

Lib.Page {
    id: page
    title: i18n("Sound output")
    contentFillsHeight: false

    footer: Lib.MoreSettingsLink {
        text: i18n("More volume settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
    }

    Volume.VolumeModels { id: models }

    Volume.OutputDeviceSection {
        Layout.fillWidth: true
        models: models
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 8
        implicitHeight: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.08)
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.bottomMargin: 6

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: i18n("Volume Mixer")
            color: Kirigami.Theme.textColor
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        PlasmaComponents3.ToolButton {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            text: i18n("More volume settings")
            display: PlasmaComponents3.AbstractButton.IconOnly
            icon.name: "configure"
            icon.width: 16
            icon.height: 16
            onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
            PlasmaComponents3.ToolTip { text: parent.text }
        }
    }

    // Master volume is present even when no application is playing audio.
    // Use the same real PulseAudio/PipeWire backend as the home slider.
    VolumeSlider {
        objectName: "wmSoundOutputMasterVolume"
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.preferredHeight: 44
        showArrow: false
        iconSize: 16
        to: 65536
    }

    Volume.VolumeMixerSection {
        Layout.fillWidth: true
        models: models
    }

    // Microphone and unsupported Windows spatial-audio functions do not
    // belong in this output-only page. Real input controls remain in KDE.
}
