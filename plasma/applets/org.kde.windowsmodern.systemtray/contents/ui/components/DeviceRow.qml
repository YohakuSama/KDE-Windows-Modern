// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

// Presentation only. Every operation is dispatched through KDE ActionsInfo.
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
    readonly property int additionalActionCount: Math.max(0, otherActions.count - (hasDefault ? 1 : 0))
    readonly property bool hasOtherActions: additionalActionCount > 0
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)

    function triggerAction(name) {
        if (canOperate && name && name.length > 0)
            actions.actionTriggered(name);
    }

    onCanOperateChanged: if (!canOperate) expanded = false

    implicitHeight: body.implicitHeight + 16
    radius: 6
    color: row.expanded ? ColorType.rowFill(dark, true, false, false)
         : pointer.hovered ? ColorType.rowFill(dark, false, true, false) : "transparent"
    border.width: row.expanded ? 1 : 0
    border.color: ColorType.divider(dark)

    HoverHandler { id: pointer }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Kirigami.Icon {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                source: row.iconName || "drive-removable-media"
                roundToIconSize: false
                color: Kirigami.Theme.textColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: row.description
                    textFormat: Text.PlainText
                    color: Kirigami.Theme.textColor
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: row.busy ? i18n("Device is busy. Do not unplug.")
                        : row.message || (row.mounted ? i18n("Mounted") : i18n("Not mounted"))
                    textFormat: Text.PlainText
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.textColor
                    opacity: 0.78
                    wrapMode: Text.Wrap
                }
            }

            PlasmaComponents3.ToolButton {
                objectName: "wmDeviceMoreActions"
                visible: row.hasOtherActions && row.canOperate
                enabled: row.canOperate
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: row.expanded ? i18n("Show less") : i18n("More actions")
                icon.name: row.expanded ? "go-up-symbolic" : "view-more-symbolic"
                icon.width: 16
                icon.height: 16
                onClicked: row.expanded = !row.expanded
                PlasmaComponents3.ToolTip { text: parent.text }
            }
        }

        PlasmaComponents3.Button {
            objectName: "wmDeviceDefaultAction"
            Layout.alignment: Qt.AlignRight
            visible: row.hasDefault && row.present
            enabled: row.canOperate
            text: row.defaultText
            onClicked: row.triggerAction(row.defaultName)
        }

        Repeater {
            id: otherActions
            model: row.actions ?? null
            delegate: PlasmaComponents3.Button {
                objectName: "wmDeviceOtherAction_" + model.Name
                required property var model
                Layout.fillWidth: true
                visible: row.expanded && row.canOperate && model.Name !== row.defaultName
                enabled: row.canOperate
                text: model.Text
                onClicked: row.triggerAction(model.Name)
            }
        }
    }
}
