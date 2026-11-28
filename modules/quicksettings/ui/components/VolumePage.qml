import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kcmutils
import "../lib" as Lib
import "../js/colorType.js" as ColorType
import "../js/trayMetrics.js" as TrayMetrics
import "volume" as Volume

Lib.Page {
    id: page

    title: i18n("Volume")
    contentFillsHeight: false

    footer: Lib.MoreSettingsLink {
        text: i18n("More volume settings")
        onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
    }

    Volume.VolumeModels {
        id: models
    }

    Volume.OutputDeviceSection {
        Layout.fillWidth: true
        models: models
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: TrayMetrics.compactRowContentInset
        Layout.rightMargin: TrayMetrics.compactRowContentInset
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        height: 1
        color: ColorType.divider(ColorType.isDark(Kirigami.Theme.backgroundColor))
        visible: models.sinkInputFilterModel.count > 0
    }

    Volume.VolumeMixerSection {
        Layout.fillWidth: true
        models: models
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: TrayMetrics.compactRowContentInset
        Layout.rightMargin: TrayMetrics.compactRowContentInset
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        height: 1
        color: ColorType.divider(ColorType.isDark(Kirigami.Theme.backgroundColor))
        visible: models.sourceAvailable
    }

    Volume.InputDeviceSection {
        Layout.fillWidth: true
        models: models
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.topMargin: 10
        text: i18n("No applications playing audio")
        color: Kirigami.Theme.textColor
        opacity: 0.75
        font.pixelSize: 12
        visible: models.sinkInputFilterModel.count === 0
        horizontalAlignment: Text.AlignHCenter
    }
}
