import QtQuick
import org.kde.notificationmanager as NotificationManager
import "../lib" as Lib
import "../js/funcs.js" as Funcs

Lib.Tile {
    id: tile

    NotificationManager.Settings {
        id: notificationSettings
    }

    // Update expiry while the flyout is open, without background polling.
    property double now: Date.now()
    Timer {
        interval: 60000
        running: tile.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: tile.now = Date.now()
    }

    readonly property bool manualDnd: Funcs.manualInhibition(notificationSettings, now)
    readonly property bool effectiveDnd: Funcs.checkInhibition(notificationSettings, now)
    label: qsTr("Do Not Disturb")
    iconSource: effectiveDnd ? "notifications-disabled" : "notifications"
    active: manualDnd

    onClicked: {
        now = Date.now();
        Funcs.toggleDnd(notificationSettings, undefined, now);
    }
    onMiddleClicked: {
        now = Date.now();
        Funcs.toggleDnd(notificationSettings, 60 * 60 * 1000, now);
    }

    tooltipText: manualDnd ? qsTr("Do Not Disturb — On")
        : effectiveDnd ? qsTr("Do Not Disturb is enabled automatically") : qsTr("Do Not Disturb — Off")
}
