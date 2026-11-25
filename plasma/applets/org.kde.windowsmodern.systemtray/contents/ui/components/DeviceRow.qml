// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../lib" as Lib

// Presentation only. All operations go through KDE's existing ActionsInfo.
Rectangle {
    id: row
    property string description
    property string iconName
    property string message
    property bool mounted: false
    property bool busy: false
    property bool present: true
    property var actions: null
    property bool expanded: false

    readonly property bool canOperate: present && !busy && !!actions
    readonly property string defaultName: actions?.defaultActionName || ""
    readonly property string defaultText: actions?.defaultActionText || ""
    readonly property bool hasDefault: defaultName.length > 0 && defaultText.length > 0
    readonly property bool hasOtherActions: otherActions.count > 0

    function triggerAction(name) {
        if (canOperate && name && name.length > 0)
            actions.actionTriggered(name);
    }

    onCanOperateChanged: if (!canOperate) expanded = false
    Lib.Win11Palette { id: fluent }

    implicitHeight: body.implicitHeight + 16
    radius: fluent.controlRadius
    color: row.expanded ? fluent.selectionFill : pointer.hovered ? fluent.controlHover : "transparent"

    HoverHandler { id: pointer }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Kirigami.Icon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: row.iconName || "drive-removable-media"
                roundToIconSize: false
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: row.description
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.defaultFont
                    color: fluent.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.busy ? i18n("Device is busy. Do not unplug.") : row.message
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    color: fluent.textSecondary
                    wrapMode: Text.Wrap
                }
            }
            Lib.FluentIconButton {
                visible: row.hasOtherActions && row.canOperate
                text: row.expanded ? i18n("Show less") : i18n("More actions")
                icon.name: row.expanded ? "go-up" : "go-down"
                onClicked: row.expanded = !row.expanded
            }
        }
        Lib.FluentButton {
            Layout.alignment: Qt.AlignRight
            Layout.maximumWidth: body.width
            visible: row.hasDefault && row.present
            enabled: row.canOperate
            text: row.defaultText
            onClicked: row.triggerAction(row.defaultName)
        }
        Repeater {
            id: otherActions
            model: row.actions ?? null
            delegate: Lib.FluentButton {
                required property var model
                Layout.fillWidth: true
                visible: row.expanded && row.canOperate && model.Name !== row.defaultName
                text: model.Text
                onClicked: row.triggerAction(model.Name)
            }
        }
    }
}
