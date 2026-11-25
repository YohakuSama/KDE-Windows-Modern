// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore

Item {
    id: root
    property var commandRunner: null
    property string errorMessage: ""
    readonly property bool opened: dialog.visible

    function open() {
        errorMessage = "";
        dialog.visible = true;
        Qt.callLater(function() {
            commandField.forceActiveFocus();
            commandField.selectAll();
        });
    }

    function close() {
        dialog.visible = false;
    }

    function submit() {
        const command = commandField.text.trim();
        if (!command) return false;
        if (!commandRunner || typeof commandRunner.runCommand !== "function") {
            errorMessage = i18n("Run service is unavailable");
            return false;
        }
        if (!commandRunner.runCommand(command)) {
            errorMessage = i18n("Command execution is blocked by system policy");
            return false;
        }
        commandField.text = "";
        errorMessage = "";
        dialog.visible = false;
        return true;
    }

    PlasmaCore.Dialog {
        id: dialog
        objectName: "wmRunDialogWindow"
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.Dialog | Qt.FramelessWindowHint
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        visible: false
        x: Math.round((Screen.width - width) / 2)
        y: Math.round((Screen.height - height) / 2)

        onVisibleChanged: if (visible) Qt.callLater(function() { commandField.forceActiveFocus(); })

        Item {
            id: panel
            width: 620
            height: root.errorMessage.length > 0 ? 104 : 88

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                height: 56
                spacing: 12

                Kirigami.Icon {
                    objectName: "wmRunDialogIcon"
                    source: Qt.resolvedUrl("run-dialog.svg")
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                }

                PlasmaComponents3.TextField {
                    id: commandField
                    objectName: "wmRunCommandField"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    placeholderText: i18n("Type the name of a command to run")
                    selectByMouse: true
                    font.pixelSize: 15
                    onAccepted: root.submit()
                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.close();
                    }
                }

                PlasmaComponents3.Button {
                    objectName: "wmRunButton"
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 44
                    text: i18n("Run")
                    icon.name: "go-next"
                    enabled: commandField.text.trim().length > 0
                    onClicked: root.submit()
                }
            }

            PlasmaComponents3.Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 64
                anchors.rightMargin: 16
                anchors.bottomMargin: 8
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                textFormat: Text.PlainText
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
