// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import "../.." as Components
import "../../lib" as Lib

ColumnLayout {
    id: section
    required property var models
    spacing: 0

    Lib.SectionHeader {
        text: i18n("Output Device")
        font.pixelSize: 14
        Layout.leftMargin: 16
        Layout.bottomMargin: 10
    }

    Repeater {
        model: section.models.sinkFilterModel
        delegate: Lib.ListRow {
            Layout.fillWidth: true
            referenceSelection: true
            selected: !!model.PulseObject && model.PulseObject.default
            // Use the device's native icon role, not an invented system glyph.
            iconSource: model.IconName || "audio-speakers"
            text: model.Description || model.Name || i18n("Unknown device")
            onClicked: {
                if (!model.PulseObject) return;
                section.models.setDefaultSink(model.PulseObject);
                section.models.playFeedback(model.PulseObject.index);
            }
        }
    }

    Lib.ListRow {
        Layout.fillWidth: true
        referenceSelection: true
        visible: section.models.sinkFilterModel.count === 0
        enabled: false
        text: i18n("No output device")
    }
}
