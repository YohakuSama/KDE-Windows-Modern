import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.brightnesscontrolplugin
import org.kde.kcmutils
import "../lib" as Lib

Lib.Page {
    id: page

    title: i18n("Brightness")
    contentFillsHeight: false

    ScreenBrightnessControl {
        id: sbControl
        isSilent: false
    }

    KeyboardBrightnessControl { id: keyboardControl }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: sbControl.displays

            delegate: ColumnLayout {
                id: display
                required property int index
                required property string displayName
                required property string label
                required property int brightness
                required property int maxBrightness
                Layout.fillWidth: true
                spacing: 4

                PlasmaComponents3.Label {
                    Layout.leftMargin: 22
                    text: display.label || i18n("Display %1", display.index + 1)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                    color: Kirigami.Theme.textColor
                }

                Lib.Slider {
                    shellAccent: page.shellAccent
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    sliderAccessibleName: display.label || i18n("Display %1", display.index + 1)
                    iconSource: "brightness-high-symbolic"
                    from: 0
                    to: display.maxBrightness
                    value: display.brightness
                    stepSize: Math.max(1, Math.floor(display.maxBrightness / 100))
                    onMoved: v => sbControl.setBrightness(display.displayName, v)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            visible: keyboardControl.isBrightnessAvailable
            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                NativeGlyph {
                    anchors.fill: parent
                    roleName: "input-keyboard-brightness"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label { text: i18n("Keyboard Backlight") }
                Lib.Slider {
                    shellAccent: page.shellAccent
                    Layout.fillWidth: true
                    sliderAccessibleName: i18n("Keyboard Backlight")
                    from: 0
                    to: keyboardControl.brightnessMax
                    value: keyboardControl.brightness
                    stepSize: 1
                    onMoved: v => keyboardControl.brightness = v
                }
            }
        }
    }

    footer: ColumnLayout {
        Lib.MoreSettingsLink {
            text: i18n("Night color settings")
            onClicked: KCMLauncher.openSystemSettings("kcm_nightlight")
        }
        Lib.MoreSettingsLink {
            text: i18n("Display settings")
            onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
        }
    }
}
