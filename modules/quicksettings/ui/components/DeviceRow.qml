// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType
import "../js/trayMetrics.js" as TrayMetrics

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
    // KDE exposes the default action separately from the additional-action model.
    readonly property int additionalActionCount: otherActions.count
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

            Item {
                Layout.preferredWidth: TrayMetrics.detailRowIconExtent
                Layout.preferredHeight: TrayMetrics.detailRowIconExtent
                Layout.alignment: Qt.AlignVCenter
                NativeGlyph {
                    id: deviceGlyph
                    anchors.fill: parent
                    roleName: row.iconName
                    fallbackRoleName: "drive-removable-media-symbolic"
                    isMask: nativeSource.endsWith("-symbolic.svg")
                }
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

            NativeToolButton {
                objectName: "wmDeviceMoreActions"
                visible: row.hasOtherActions && row.canOperate
                enabled: row.canOperate
                nativeRole: row.expanded ? "go-up-symbolic" : "view-more-symbolic"
                text: row.expanded ? i18n("Show less") : i18n("More actions")
                icon.width: 16
                icon.height: 16
                onClicked: row.expanded = !row.expanded
                PlasmaComponents3.ToolTip { text: parent.text }
            }
        }

        PlasmaComponents3.Button {
            id: defaultAction
            objectName: "wmDeviceDefaultAction"
            Layout.alignment: Qt.AlignRight
            visible: row.hasDefault && row.present
            enabled: row.canOperate
            text: row.defaultText
            // Backend actions can carry arbitrary KDE icons; show only
            // roles that resolve in the private Windows import.
            icon.source: defaultActionPaint.nativeSource
            contentItem: NativeButtonContent {
                id: defaultActionPaint
                button: defaultAction
                roleName: row.actions?.defaultActionIcon || ""
            }
            onClicked: row.triggerAction(row.defaultName)
        }

        Repeater {
            id: otherActions
            model: row.actions ?? null
            delegate: PlasmaComponents3.Button {
                id: otherAction
                // Native KDE DeviceItem uses the delegate model object for
                // these uppercase role names. QML property names cannot
                // start with uppercase letters.
                required property var model
                objectName: "wmDeviceOtherAction_" + model.Name
                Layout.fillWidth: true
                visible: row.expanded && row.canOperate
                enabled: row.canOperate
                text: model.Text
                icon.source: otherActionPaint.nativeSource
                contentItem: NativeButtonContent {
                    id: otherActionPaint
                    button: otherAction
                    roleName: otherAction.model.Icon || ""
                }
                onClicked: row.triggerAction(model.Name)
            }
        }
    }
}
