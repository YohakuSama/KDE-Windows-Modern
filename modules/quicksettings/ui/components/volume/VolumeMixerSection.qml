import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../../lib" as Lib
import ".." as Components
import "../../js/colorType.js" as ColorType

ColumnLayout {
    id: section

    property var models
    property bool hasApps: models.sinkInputFilterModel.count > 0

    spacing: 0
    visible: hasApps

    Lib.SectionHeader {
        text: i18n("Volume Mixer")
    }

    Repeater {
        model: models.sinkInputFilterModel

        delegate: Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                radius: 4
                color: ColorType.rowFill(ColorType.isDark(Kirigami.Theme.backgroundColor),
                    false, rowHover.hovered, false)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Item {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        // Preserve genuine application branding. Only the
                        // generic system fallback comes from Windows.
                        Kirigami.Icon {
                            anchors.fill: parent
                            source: model.IconName || ""
                            fallback: ""
                            visible: !!model.IconName && valid
                            isMask: false
                            roundToIconSize: false
                            id: applicationIcon
                        }
                        Components.NativeGlyph {
                            anchors.fill: parent
                            roleName: "audio-volume-high-symbolic"
                            visible: !applicationIcon.visible && nativeSource.length > 0
                        }
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: (model.Client && model.Client.name) || model.Name || i18n("Unknown application")
                        textFormat: Text.PlainText
                        color: Kirigami.Theme.textColor
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Lib.Slider {
                        Layout.preferredWidth: 110
                        sliderAccessibleName: (model.Client && model.Client.name) || model.Name || i18n("Unknown application")
                        from: 0
                        to: 65536
                        value: model.Volume
                        stepSize: Math.round(65536 / 100)
                        onMoved: v => {
                            model.Volume = v;
                            model.Muted = v === 0;
                        }
                        onReleased: section.models.playFeedback(model.DeviceIndex)
                    }
                }

                HoverHandler { id: rowHover }
            }
        }
    }
}
