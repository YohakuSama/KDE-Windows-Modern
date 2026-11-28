import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../../lib" as Lib
import ".." as Components
import "../../js/colorType.js" as ColorType
import "../../js/controlMetrics.js" as ControlMetrics
import "../../js/trayMetrics.js" as TrayMetrics

ColumnLayout {
    id: section

    property var models
    property color shellAccent: Kirigami.Theme.highlightColor
    property bool hasApps: models.sinkInputFilterModel.count > 0
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property color accent: ColorType.accentForSurface(shellAccent,
        Qt.color(ColorType.cardFill(dark, false)))

    spacing: 0
    visible: hasApps

    Lib.SectionHeader {
        text: i18n("Volume Mixer")
    }

    Repeater {
        model: models.sinkInputFilterModel

        delegate: Item {
            id: appRow
            required property var model
            readonly property string appName: (model.Client && model.Client.name) || model.Name || i18n("Unknown application")
            Layout.fillWidth: true
            Layout.preferredHeight: TrayMetrics.quickSliderRowHeight

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: TrayMetrics.detailRowOuterInset
                anchors.rightMargin: TrayMetrics.detailRowOuterInset
                radius: ControlMetrics.controlCornerRadius
                color: ColorType.rowFill(section.dark, false, rowHover.hovered, false)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: TrayMetrics.compactRowContentInset
                    anchors.rightMargin: TrayMetrics.compactRowContentInset
                    spacing: TrayMetrics.compactRowSpacing

                    Item {
                        id: appMuteSlot
                        objectName: "wmVolumeMixerAppMuteButton"
                        Layout.preferredWidth: TrayMetrics.compactRowIconExtent
                        Layout.preferredHeight: TrayMetrics.compactRowIconExtent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: appRow.model.Muted
                            ? i18n("Unmute %1", appRow.appName) : i18n("Mute %1", appRow.appName)
                        Accessible.onPressAction: appRow.model.Muted = !appRow.model.Muted
                        Keys.onReturnPressed: event => {
                            if (!event.isAutoRepeat) appRow.model.Muted = !appRow.model.Muted;
                        }
                        Keys.onEnterPressed: event => {
                            if (!event.isAutoRepeat) appRow.model.Muted = !appRow.model.Muted;
                        }
                        Keys.onSpacePressed: event => {
                            if (!event.isAutoRepeat) appRow.model.Muted = !appRow.model.Muted;
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: ControlMetrics.controlCornerRadius
                            color: "transparent"
                            border.width: appMuteSlot.activeFocus ? 1 : 0
                            border.color: section.accent
                        }
                        // Preserve genuine application branding. Only the
                        // generic system fallback comes from Windows.
                        Kirigami.Icon {
                            anchors.fill: parent
                            source: appRow.model.IconName || ""
                            fallback: ""
                            visible: !!appRow.model.IconName && valid
                            opacity: appRow.model.Muted ? 0.45 : 1
                            isMask: false
                            roundToIconSize: false
                            id: applicationIcon
                        }
                        Components.NativeGlyph {
                            anchors.fill: parent
                            roleName: appRow.model.Muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                            opacity: appRow.model.Muted ? 0.65 : 1
                            visible: !applicationIcon.visible && nativeSource.length > 0
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: appRow.model.Muted = !appRow.model.Muted
                        }
                        PlasmaComponents3.ToolTip {
                            visible: appMuteHover.hovered
                            text: appMuteSlot.Accessible.name
                        }
                        HoverHandler { id: appMuteHover }
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        text: appRow.appName
                        textFormat: Text.PlainText
                        color: Kirigami.Theme.textColor
                        opacity: appRow.model.Muted ? 0.65 : 1
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Lib.Slider {
                        Layout.preferredWidth: 110
                        shellAccent: section.shellAccent
                        sliderAccessibleName: appRow.appName
                        from: 0
                        to: 65536
                        value: appRow.model.Muted ? 0 : appRow.model.Volume
                        stepSize: Math.round(65536 / 100)
                        onMoved: v => {
                            appRow.model.Volume = v;
                            appRow.model.Muted = v === 0;
                        }
                        onReleased: section.models.playFeedback(appRow.model.DeviceIndex)
                    }
                }

                HoverHandler { id: rowHover }
            }
        }
    }
}
