// On-screen keyboard toggle (Windows' login screen offers it under its
// accessibility button). Shown only when a virtual keyboard is available.
// Loaded through a Loader: if the module is missing, only this button goes.
import QtQuick
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import "lockText.js" as LockText

StatusIconButton {
    readonly property bool available: Keyboards.KWinVirtualKeyboard.available
    enabled: available
    focusPolicy: Qt.TabFocus
    icon.name: "preferences-desktop-accessibility-symbolic"
    text: LockText.tr("Accessibility", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Accessibility"), Qt.uiLanguage, Qt.locale().name)
    onClicked: if (available) Keyboards.KWinVirtualKeyboard.active = !Keyboards.KWinVirtualKeyboard.active
}
