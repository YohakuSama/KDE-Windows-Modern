import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.volume as Vol
import org.kde.kcmutils
import "../lib" as Lib
import "../js/funcs.js" as Funcs
import "volume" as Volume

Lib.Slider {
    id: root

    Volume.OutputSink { id: output }
    readonly property var sink: output.sink
    readonly property bool sinkAvailable: output.available

    sliderAccessibleName: i18n("Volume")
    iconSource: Funcs.volIconName(sinkAvailable ? sink.volume : 0, sinkAvailable ? sink.muted : true)
    showArrow: true
    soundOutputDetails: true
    detailsAccessibleName: i18n("Sound output")
    iconClickable: sinkAvailable
    iconAccessibleName: sinkAvailable && sink.muted ? i18n("Unmute") : i18n("Mute")

    readonly property int maxVol: sinkAvailable && sink.canRaiseVolume ? 98304 : 65536

    trackEnabled: sinkAvailable
    from: 0
    to: maxVol
    value: sinkAvailable ? sink.volume : 0
    stepSize: Math.round(maxVol / 100)

    onMoved: function (v) {
        if (!sinkAvailable) return;
        sink.volume = v;
        sink.muted = v === 0;
        if (!pressed && sinkAvailable)
            feedback.play(sink.index);
    }

    onReleased: {
        if (sinkAvailable)
            feedback.play(sink.index);
    }

    Vol.VolumeFeedback {
        id: feedback
    }

    onIconClicked: {
        if (sinkAvailable)
            sink.muted = !sink.muted;
    }

    onRightClicked: volumeMenu.popup()

    onMiddleClicked: {
        if (sinkAvailable)
            sink.muted = !sink.muted;
    }

    PlasmaComponents3.Menu {
        id: volumeMenu

        NativeMenuItem {
            text: sinkAvailable && sink.muted ? i18n("Unmute") : i18n("Mute")
            enabled: root.sinkAvailable
            nativeRole: sinkAvailable && sink.muted ? "audio-volume-muted" : "audio-volume-high"
            onClicked: {
                if (sinkAvailable)
                    sink.muted = !sink.muted;
            }
        }
        NativeMenuItem {
            text: i18n("Test sound")
            nativeRole: "audio-volume-high"
            enabled: root.sinkAvailable
            onClicked: if (root.sinkAvailable) feedback.play(root.sink.index)
        }
        NativeMenuItem {
            text: i18n("Audio settings")
            nativeRole: "configure"
            onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
        }
    }
}
