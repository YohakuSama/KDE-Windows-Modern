/***************************************************************************
 *   License: GPL-3.0-or-later
 *   Author: Jeysef
 *
 *   Configurable folder/system shortcuts in the Start footer.
 ***************************************************************************/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/theme.js" as Theme

Item {
    id: placesRow

    property var executable: null

    readonly property var allLocations: [
        { text: QT_TR_NOOP("Home"),          icon: "user-home",             command: 'xdg-open "$HOME"' },
        { text: QT_TR_NOOP("Documents"),      icon: "folder-documents",     command: 'xdg-open "$(xdg-user-dir DOCUMENTS)"' },
        { text: QT_TR_NOOP("Pictures"),       icon: "folder-pictures",      command: 'xdg-open "$(xdg-user-dir PICTURES)"' },
        { text: QT_TR_NOOP("Music"),          icon: "folder-music",         command: 'xdg-open "$(xdg-user-dir MUSIC)"' },
        { text: QT_TR_NOOP("Downloads"),      icon: "folder-download",      command: 'xdg-open "$(xdg-user-dir DOWNLOAD)"' },
        { text: QT_TR_NOOP("Recent Items"),   icon: "document-open-recent", command: "dolphin recentlyused:/files" },
        { text: QT_TR_NOOP("This PC"),        icon: "computer",             command: "dolphin" },
        { text: QT_TR_NOOP("Update"),         icon: "system-software-update", command: "plasma-discover" },
        { text: QT_TR_NOOP("Terminal"),       icon: "utilities-terminal",   command: "T=$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication); command -v ${T:-konsole} >/dev/null 2>&1 && exec ${T:-konsole} || exec alacritty" },
        { text: QT_TR_NOOP("Run..."),         icon: "system-run",           command: "krunner" }
    ]

    readonly property var allKeys: ["home","documents","pictures","music","downloads","recent","thispc","update","terminal","run"]

    readonly property var visibleLocations: {
        var items = Plasmoid.configuration.rightColumnItems;
        if (!items || items.length === 0) {
            return allLocations;
        }
        var out = [];
        for (var i = 0; i < items.length; i++) {
            var idx = allKeys.indexOf(items[i]);
            if (idx >= 0) {
                out.push(allLocations[idx]);
            }
        }
        return out.length > 0 ? out : allLocations;
    }

    implicitHeight: Kirigami.Units.gridUnit * 2
    implicitWidth: buttons.implicitWidth

    Flickable {
        anchors.fill: parent
        contentWidth: buttons.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Row {
            id: buttons
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: placesRow.visibleLocations
                delegate: PlasmaComponents3.ToolButton {
                    required property var modelData
                    width: Kirigami.Units.gridUnit * 2
                    height: width
                    text: i18n(modelData.text)
                    icon.name: modelData.icon
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    PlasmaComponents3.ToolTip { text: parent.text }
                    onClicked: {
                        if (placesRow.executable && modelData.command)
                            placesRow.executable.exec(modelData.command);
                        root.closeMenu();
                    }
                }
            }
        }
    }
}
