import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../../lib" as Lib
import ".." as Components
import "../../js/funcs.js" as Funcs
import "../../js/trayMetrics.js" as TrayMetrics

ColumnLayout {
    id: section

    property var models
    property bool expanded: false
    // A single available device must remain selectable if the preferred
    // backend device is temporarily absent or unusable.
    readonly property bool hasMultiple: models.sinkFilterModel.count > 1
        || (models.sinkFilterModel.count > 0 && !models.sinkAvailable)
    onHasMultipleChanged: if (!hasMultiple) expanded = false

    spacing: 0

    Lib.SectionHeader {
        text: i18n("Output Device")
    }

    Lib.ListRow {
        Layout.fillWidth: true
        selected: models.sinkAvailable
        enabled: section.hasMultiple
        iconSource: Funcs.volIconName(
            models.sinkAvailable ? models.sink.volume : 0,
            models.sinkAvailable ? models.sink.muted : true
        )
        text: models.sinkAvailable ? models.sink.description : i18n("No output device")
        trailing: section.hasMultiple ? arrowComponent : null
        onClicked: if (section.hasMultiple) section.expanded = !section.expanded
    }

    Component {
        id: arrowComponent
        Components.NativeGlyph {
            width: TrayMetrics.sectionChevronExtent
            height: TrayMetrics.sectionChevronExtent
            roleName: "go-down-symbolic"
            rotation: section.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: Kirigami.Units.shortDuration > 0 ? TrayMetrics.sectionChevronRotateDuration : 0 }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: section.expanded ? deviceList.implicitHeight : 0
        clip: true
        visible: section.expanded || height > 0
        enabled: section.expanded

        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: Kirigami.Units.shortDuration > 0 ? TrayMetrics.sectionExpandDuration : 0; easing.type: Easing.OutQuad }
        }

        ColumnLayout {
            id: deviceList
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: models.sinkFilterModel

                delegate: Lib.ListRow {
                    Layout.fillWidth: true
                    selected: model.PulseObject && model.PulseObject.default
                    iconSource: Funcs.volIconName(model.Volume, model.Muted)
                    text: model.Description || model.Name || i18n("Unknown device")
                    onClicked: {
                        const device = model.PulseObject;
                        if (models.setDefaultSink(device)) {
                            models.playFeedback(device.index);
                            section.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
