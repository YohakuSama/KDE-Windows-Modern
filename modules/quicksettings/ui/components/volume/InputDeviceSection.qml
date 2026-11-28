import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.volume as Vol
import "../../lib" as Lib
import ".." as Components
import "../../js/trayMetrics.js" as TrayMetrics

ColumnLayout {
    id: section

    property var models
    property bool expanded: false
    // A single available device must remain selectable if the preferred
    // backend device is temporarily absent or unusable.
    readonly property bool hasMultiple: models.sourceFilterModel.count > 1
        || (models.sourceFilterModel.count > 0 && !models.sourceAvailable)
    onHasMultipleChanged: if (!hasMultiple) expanded = false

    spacing: 0

    Lib.SectionHeader {
        text: i18n("Input Device")
    }

    Lib.ListRow {
        Layout.fillWidth: true
        selected: models.sourceAvailable
        enabled: section.hasMultiple
        iconSource: models.sourceAvailable && !models.source.muted ? "microphone-sensitivity-high-symbolic" : "microphone-sensitivity-muted-symbolic"
        text: models.sourceAvailable ? models.source.description : i18n("No input device")
        trailing: section.hasMultiple ? arrowComponent : null
        onClicked: if (section.hasMultiple)
            section.expanded = !section.expanded
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
            NumberAnimation {
                duration: Kirigami.Units.shortDuration > 0 ? TrayMetrics.sectionExpandDuration : 0
                easing.type: Easing.OutQuad
            }
        }

        ColumnLayout {
            id: deviceList
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Repeater {
                model: models.sourceFilterModel

                delegate: Lib.ListRow {
                    Layout.fillWidth: true
                    selected: model.PulseObject && model.PulseObject.default
                    iconSource: model.Muted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic"
                    text: model.Description || model.Name || i18n("Unknown device")
                    onClicked: {
                        if (models.setDefaultSource(model.PulseObject))
                            section.expanded = false;
                    }
                }
            }
        }
    }
}
