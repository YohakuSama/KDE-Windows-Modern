/*
    Quick Settings footer, as in Windows 11: battery level on the left
    (laptops only; opens the battery page) and a Settings gear on the right
    (System Settings; right-click for the common pages). No power button:
    that lives in Start, as on Windows.
*/
import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kcmutils
import "../lib" as Lib
import "." as Components

Rectangle {
    id: footer

    property real uiScale: 1
    property bool showBattery: true

    signal batteryClicked

    // Subtle footer tint on either scheme, separate from the slider region.
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b, 0.02)
    implicitHeight: Math.round(48 * uiScale)

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    }

    Components.Battery {
        id: battery
        anchors.left: parent.left
        anchors.leftMargin: Math.round(20 * footer.uiScale)
        anchors.verticalCenter: parent.verticalCenter
        visible: footer.showBattery && battery.hasBattery
        opacity: batteryMouse.containsMouse ? 1 : 0.85

        Accessible.role: Accessible.Button
        Accessible.name: battery.percentKnown ? i18n("Battery %1%", battery.percent) : i18n("Battery level unknown")
        Accessible.onPressAction: footer.batteryClicked()
        activeFocusOnTab: visible
        Keys.onReturnPressed: footer.batteryClicked()
        Keys.onEnterPressed: footer.batteryClicked()
        Keys.onSpacePressed: footer.batteryClicked()

        MouseArea {
            id: batteryMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: footer.batteryClicked()
        }
    }

    Lib.FooterButton {
        id: settingsBtn
        anchors.right: parent.right
        anchors.rightMargin: Math.round(20 * footer.uiScale)
        anchors.verticalCenter: parent.verticalCenter
        buttonSize: Math.round(18 * footer.uiScale)
        iconSource: "configure"
        tooltipText: i18n("All settings")
        Accessible.role: Accessible.Button
        Accessible.name: i18n("All settings")
        onClicked: KCMLauncher.openSystemSettings("")
        onRightClicked: gearMenu.popup()
    }

    PlasmaComponents3.Menu {
        id: gearMenu

        PlasmaComponents3.MenuItem {
            text: i18n("Display settings")
            icon.name: "preferences-desktop-display"
            onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Sound settings")
            icon.name: "audio-volume-high"
            onClicked: KCMLauncher.openSystemSettings("kcm_pulseaudio")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Network settings")
            icon.name: "network-wireless"
            onClicked: KCMLauncher.openSystemSettings("kcm_networkmanagement")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Power settings")
            icon.name: "battery"
            onClicked: KCMLauncher.openSystemSettings("kcm_powerdevilprofilesconfig")
        }
        PlasmaComponents3.MenuItem {
            text: i18n("Notification settings")
            icon.name: "notifications"
            onClicked: KCMLauncher.openSystemSettings("kcm_notifications")
        }
    }
}
