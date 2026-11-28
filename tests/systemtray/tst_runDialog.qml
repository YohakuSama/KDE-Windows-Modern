// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Tray
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/controlMetrics.js" as ControlMetrics

Item {
    width: 800
    height: 400
    QtObject {
        id: runner
        property string lastCommand: ""
        property int launches: 0
        property bool accepts: true
        function runCommand(command) {
            if (!accepts) return false;
            lastCommand = command;
            launches++;
            return true;
        }
    }
    Tray.RunDialog {
        id: runDialog
        commandRunner: runner
    }
    TestCase {
        name: "WindowsModernRunDialog"
        when: windowShown
        function init() {
            runner.launches = 0;
            runner.accepts = true;
            runDialog.commandRunner = runner;
            runDialog.commandHistory = [];
            runDialog.commandText = "";
        }
        function cleanup() { runDialog.close(); }
        function test_runButtonUsesSharedControlRadius() {
            const button = findChild(runDialog, "wmRunButton");
            const cancelButton = findChild(runDialog, "wmRunCancelButton");
            verify(button);
            verify(cancelButton);
            compare(button.background.radius, ControlMetrics.controlCornerRadius);
            compare(cancelButton.background.radius, ControlMetrics.controlCornerRadius);
        }
        function test_submitOnce() {
            runDialog.commandText = "  konsole --new-tab  ";
            verify(runDialog.canRun);
            verify(runDialog.submit());
            compare(runner.lastCommand, "konsole --new-tab");
            compare(runner.launches, 1);
            compare(runDialog.commandText, "");
            verify(!runDialog.submit());
            compare(runner.launches, 1);
        }
        function test_emptyAndBlocked() {
            runDialog.commandText = "   ";
            verify(!runDialog.canRun);
            verify(!runDialog.submit());
            compare(runner.launches, 0);
            runDialog.commandText = "konsole";
            runner.accepts = false;
            verify(!runDialog.submit());
            verify(runDialog.errorMessage.length > 0);
            compare(runDialog.commandText, "konsole");
            compare(runner.launches, 0);
            runDialog.commandRunner = null;
            verify(!runDialog.submit());
            verify(runDialog.errorMessage.length > 0);
        }
        function test_positionAcrossOutputs() {
            runDialog.workArea = Qt.rect(-1200, 100, 1200, 700);
            runDialog.positionWindow();
            let g = runDialog.windowGeometry;
            compare(g.x, Math.round(-1200 + Math.max(0, (1200 - g.width) / 2)));
            compare(g.y, Math.round(100 + Math.max(0, (700 - g.height) / 2)));
        }
        function test_historyNavigationAndDeduplication() {
            runDialog.commandText = "dolphin";
            verify(runDialog.submit());
            runDialog.commandText = "konsole";
            verify(runDialog.submit());
            runDialog.commandText = "  dolphin  ";
            verify(runDialog.submit());
            compare(runDialog.commandHistory, ["dolphin", "konsole"]);

            runDialog.open(Qt.rect(0, 0, 800, 400));
            const field = findChild(runDialog, "wmRunCommandField");
            verify(field);
            field.forceActiveFocus();
            field.text = "draft";
            keyClick(Qt.Key_Up);
            compare(field.text, "dolphin");
            keyClick(Qt.Key_Up);
            compare(field.text, "konsole");
            keyClick(Qt.Key_Down);
            compare(field.text, "dolphin");
            keyClick(Qt.Key_Down);
            compare(field.text, "draft");
        }
        function test_cancelClearsErrorAndCloses() {
            runDialog.open(Qt.rect(0, 0, 800, 400));
            verify(runDialog.opened);
            runner.accepts = false;
            runDialog.commandText = "blocked-cmd";
            verify(!runDialog.submit());
            verify(runDialog.errorMessage.length > 0);
            runDialog.cancel();
            verify(!runDialog.opened);
            compare(runDialog.errorMessage, "");
        }
    }
}
