// On-screen keyboard toggle (Windows' login screen offers it under its
// accessibility button). Shown only when a virtual keyboard is available.
// Loaded through a Loader: if the module is missing, only this button goes.
import QtQuick
import org.kde.plasma.workspace.keyboardlayout as Keyboards

StatusIconButton {
    readonly property bool available: Keyboards.KWinVirtualKeyboard.available
    visible: available
    focusPolicy: Qt.TabFocus
    icon.name: "preferences-desktop-accessibility-symbolic"
    text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "On-screen keyboard")
    onClicked: Keyboards.KWinVirtualKeyboard.active = !Keyboards.KWinVirtualKeyboard.active
}
