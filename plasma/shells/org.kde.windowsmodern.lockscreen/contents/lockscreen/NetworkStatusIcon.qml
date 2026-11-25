// Live network icon (the same icon the tray's network applet shows).
// Loaded through a Loader: if plasma-nm is missing, only this icon goes.
import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "lockText.js" as LockText

StatusIconButton {
    PlasmaNM.ConnectionIcon {
        id: connection
    }
    icon.name: {
        const name = connection.connectionIcon || "network-unavailable";
        return name.endsWith("-symbolic") ? name : name + "-symbolic";
    }
    text: LockText.tr("Network", i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Network"), Qt.uiLanguage, Qt.locale().name)
}
