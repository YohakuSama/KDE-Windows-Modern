// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import "../js/controlMetrics.js" as ControlMetrics

Item {
    id: root
    property var commandRunner: null
    property rect workArea: Qt.rect(0, 0, 0, 0)
    property string errorMessage: ""
    property alias commandText: commandField.text
    readonly property bool opened: dialog.visible
    readonly property rect windowGeometry: Qt.rect(dialog.x, dialog.y, dialog.width, dialog.height)
    readonly property bool canRun: commandText.trim().length > 0 && !commandField.inputMethodComposing

    function positionWindow() {
        if (workArea.width <= 0 || workArea.height <= 0) return;
        dialog.x = Math.round(workArea.x + Math.max(0, (workArea.width - dialog.width) / 2));
        dialog.y = Math.round(workArea.y + Math.max(0, (workArea.height - dialog.height) / 2));
    }
    function open(area) {
        if (!area || area.width <= 0 || area.height <= 0) return;
        workArea = area;
        errorMessage = "";
        positionWindow();
        dialog.visible = true;
        positionWindow();
        Qt.callLater(function() {
            if (!root.opened) return;
            commandField.forceActiveFocus();
            commandField.selectAll();
        });
    }
    function close() { dialog.visible = false; }
    function submit() {
        if (!canRun) return false;
        if (!commandRunner || typeof commandRunner.runCommand !== "function") {
            errorMessage = i18n("Run service is unavailable");
            return false;
        }
        if (!commandRunner.runCommand(commandText.trim())) {
            errorMessage = i18n("Command execution is blocked by system policy");
            return false;
        }
        close();
        commandText = "";
        errorMessage = "";
        return true;
    }

    PlasmaCore.Dialog {
        id: dialog
        objectName: "wmRunDialogWindow"
        type: PlasmaCore.Dialog.AppletPopup
        flags: Qt.Dialog
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        visible: false
        onWidthChanged: if (visible) root.positionWindow()
        onHeightChanged: if (visible) root.positionWindow()

        Item {
            id: panel
            width: Math.max(1, Math.min(620, root.workArea.width - 24 - dialog.margins.left - dialog.margins.right))
            height: root.errorMessage.length ? 86 : 62

            Keys.onEscapePressed: event => {
                if (commandField.inputMethodComposing) { event.accepted = false; return; }
                event.accepted = true;
                root.close();
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: 62
                spacing: 12

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.minimumWidth: 0
                    visible: runGlyph.nativeSource.length > 0
                    NativeGlyph {
                        id: runGlyph
                        objectName: "wmRunGlyph"
                        anchors.fill: parent
                        roleName: "system-run"
                    }
                }

                PlasmaComponents3.TextField {
                    id: commandField
                    objectName: "wmRunCommandField"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 40
                    placeholderText: i18n("Type the name of a command to run")
                    Accessible.name: placeholderText
                    selectByMouse: true
                    font.pixelSize: 15
                    background: Rectangle { color: "transparent" }
                    onAccepted: root.submit()
                }

                PlasmaComponents3.Button {
                    id: runButton
                    objectName: "wmRunButton"
                    Layout.preferredWidth: 94
                    Layout.minimumWidth: 60
                    Layout.preferredHeight: 38
                    text: i18n("Run") + "  ↵"
                    Accessible.name: i18n("Run")
                    enabled: root.canRun
                    background: Rectangle {
                        radius: ControlMetrics.controlCornerRadius
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                            Kirigami.Theme.textColor.b, runButton.down ? 0.15
                                : runButton.hovered ? 0.10 : runButton.enabled ? 0.07 : 0.04)
                        border.width: 1
                        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                            Kirigami.Theme.textColor.b, runButton.activeFocus ? 0.5 : 0.06)
                    }
                    onClicked: root.submit()
                }
            }
            PlasmaComponents3.Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 6
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                textFormat: Text.PlainText
                color: Kirigami.Theme.negativeTextColor
                elide: Text.ElideRight
            }
        }
    }
}
