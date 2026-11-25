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
import "../js/colorType.js" as ColorType

Rectangle {
    id: footer

    property real uiScale: 1
    property bool showBattery: true
    property real frameInset: 0
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property real outerRadius: frameInset > 0 ? frameInset : Math.round(8 * uiScale)
    readonly property real sideInset: Math.max(8, Math.round(24 * uiScale) - frameInset)

    signal batteryClicked

    color: "transparent"
    implicitHeight: Math.round(48 * uiScale)

    // One subtle tint over the native/custom base. Extend it into the
    // native frame inset without painting over the one-pixel outline.
    Rectangle {
        id: footerSurface
        objectName: "wmQuickSettingsFooterSurface"
        x: 1 - footer.frameInset
        y: 0
        width: Math.max(0, footer.width + 2 * footer.frameInset - 2)
        height: Math.max(0, footer.height + footer.frameInset - 1)
        radius: Math.max(0, footer.outerRadius - 1)
        topLeftRadius: 0
        topRightRadius: 0
        color: ColorType.footerTint(footer.dark)
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: ColorType.divider(footer.dark)
        }
    }

    Components.Battery {
        id: battery
        anchors.left: parent.left
        anchors.leftMargin: footer.sideInset
        anchors.verticalCenter: parent.verticalCenter
        visible: footer.showBattery && battery.hasBattery
        glyphSize: Math.round(16 * footer.uiScale)
        labelPixelSize: Math.round(12 * footer.uiScale)
        opacity: 1

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
        anchors.rightMargin: Math.max(0, footer.sideInset - (settingsBtn.hitSize - settingsBtn.buttonSize) / 2)
        anchors.verticalCenter: parent.verticalCenter
        buttonSize: Math.round(16 * footer.uiScale)
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
