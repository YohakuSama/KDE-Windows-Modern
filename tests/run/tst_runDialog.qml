// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.run/contents/ui"

Item {
    width: 800
    height: 400

    QtObject {
        id: runner
        property string lastCommand: ""
        property bool accepts: true
        function runCommand(command) {
            lastCommand = command;
            return accepts;
        }
    }

    RunDialog {
        id: runDialog
        commandRunner: runner
    }

    TestCase {
        name: "WindowsModernRunDialog"
        when: windowShown

        function test_submitCommandAndClose() {
            runDialog.open();
            tryCompare(runDialog, "opened", true);
            const field = findChild(runDialog, "wmRunCommandField");
            const icon = findChild(runDialog, "wmRunDialogIcon");
            verify(field && icon);
            field.text = "konsole --new-tab";
            verify(runDialog.submit());
            compare(runner.lastCommand, "konsole --new-tab");
            tryCompare(runDialog, "opened", false);
            compare(field.text, "");
        }

        function test_emptyCommandDoesNotLaunch() {
            const previous = runner.lastCommand;
            runDialog.open();
            const field = findChild(runDialog, "wmRunCommandField");
            field.text = "   ";
            compare(runDialog.submit(), false);
            compare(runner.lastCommand, previous);
            runDialog.close();
        }

        function test_authorizationFailureStaysOpen() {
            runner.accepts = false;
            runDialog.open();
            const field = findChild(runDialog, "wmRunCommandField");
            field.text = "konsole";
            compare(runDialog.submit(), false);
            tryCompare(runDialog, "opened", true);
            verify(runDialog.errorMessage.length > 0);
            runner.accepts = true;
            runDialog.close();
        }

        function test_missingRunnerShowsError() {
            runDialog.commandRunner = null;
            runDialog.open();
            const field = findChild(runDialog, "wmRunCommandField");
            field.text = "konsole";
            compare(runDialog.submit(), false);
            compare(runDialog.errorMessage, "Run service is unavailable");
            runDialog.commandRunner = runner;
            runDialog.close();
        }
    }
}
