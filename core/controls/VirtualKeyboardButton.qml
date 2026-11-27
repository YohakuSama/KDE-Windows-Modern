// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import "lockText.js" as LockText

// Shared greeter/lock-screen action. Keep it behind each host's Loader so a
// missing optional keyboard module cannot prevent the rest of the shell.
StatusIconButton {
    id: button
    readonly property bool available: Keyboards.KWinVirtualKeyboard.available
    // The greeter hides an unavailable action; the lock screen keeps a
    // disabled Accessibility entry, matching its native footer behavior.
    property bool lockScreenPresentation: false

    visible: lockScreenPresentation || available
    enabled: available
    focusPolicy: Qt.TabFocus
    icon.name: "preferences-desktop-accessibility-symbolic"
    text: lockScreenPresentation
        ? LockText.tr("Accessibility",
            i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Accessibility"),
            Qt.uiLanguage, Qt.locale().name)
        : i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "On-screen keyboard")
    onClicked: {
        if (available)
            Keyboards.KWinVirtualKeyboard.active = !Keyboards.KWinVirtualKeyboard.active;
    }
}
