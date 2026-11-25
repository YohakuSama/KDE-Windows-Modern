import QtQuick
import org.kde.plasma.private.batterymonitor
import "../lib" as Lib

Lib.Tile {
    id: tile

    PowerProfilesControl {
        id: powerProfiles
    }

    readonly property bool saverOn: powerProfiles.activeProfile === "power-saver"
    readonly property bool available: powerProfiles.isPowerProfileDaemonInstalled && powerProfiles.profiles.indexOf("power-saver") >= 0

    property string previousProfile: ""
    visible: available
    readonly property bool toggleAvailable: available && powerProfiles.profiles.some(name => name !== "power-saver")
    label: i18n("Battery Saver")
    // Use the power-saving role, not a low-charge battery indicator.
    iconSource: "wm-energy-saver-symbolic"
    active: saverOn

    onClicked: {
        if (!toggleAvailable) return;
        if (saverOn) {
            const profile = [previousProfile, powerProfiles.configuredProfile, "balanced", ...powerProfiles.profiles]
                .find(name => name && name !== "power-saver" && powerProfiles.profiles.includes(name));
            if (profile) powerProfiles.setProfile(profile);
        } else {
            previousProfile = powerProfiles.activeProfile;
            powerProfiles.setProfile("power-saver");
        }
    }

    tooltipText: {
        switch (powerProfiles.activeProfile) {
        case "performance":
            return i18n("Power Mode — Performance");
        case "power-saver":
            return i18n("Power Mode — Power Saver");
        default:
            return i18n("Power Mode — Balanced");
        }
    }
}
