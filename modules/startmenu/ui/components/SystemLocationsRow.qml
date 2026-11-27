// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "../code/footerLocations.js" as Locations

Item {
    id: placesRow
    property var executable: null
    signal shortcutInvoked

    readonly property var selectedKeys: Locations.normalize(Plasmoid.configuration.rightColumnItems)
    readonly property var visibleLocations: Locations.locations(i18n)
        .filter(location => selectedKeys.indexOf(location.key) >= 0)
    readonly property int buttonExtent: Math.max(24, Math.min(32,
        Math.floor(width / Math.max(1, visibleLocations.length))))
    implicitHeight: 40
    implicitWidth: visibleLocations.length * 32

    function resolveFolder(key) {
        switch (key) {
        case "documents": return StandardPaths.writableLocation(StandardPaths.DocumentsLocation);
        case "downloads": return StandardPaths.writableLocation(StandardPaths.DownloadLocation);
        case "music": return StandardPaths.writableLocation(StandardPaths.MusicLocation);
        case "pictures": return StandardPaths.writableLocation(StandardPaths.PicturesLocation);
        case "videos": return StandardPaths.writableLocation(StandardPaths.MoviesLocation);
        case "home": return StandardPaths.writableLocation(StandardPaths.HomeLocation);
        default: return "";
        }
    }

    function launch(location) {
        return Locations.invoke(location, key => resolveFolder(key),
            url => Qt.openUrlExternally(url),
            command => !!executable && executable.exec(command) === true);
    }

    Flickable {
        id: locationsView
        anchors.fill: parent
        contentWidth: Math.max(width, buttons.implicitWidth)
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Row {
            id: buttons
            x: Math.max(0, placesRow.width - implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Repeater {
                model: placesRow.visibleLocations
                delegate: PlasmaComponents3.ToolButton {
                    id: shortcut
                    required property var modelData
                    width: placesRow.buttonExtent
                    height: 36
                    text: modelData.text
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    padding: 0
                    enabled: modelData.folder ? String(placesRow.resolveFolder(modelData.folder)).length > 0
                        : !!placesRow.executable && !!modelData.command
                    onActiveFocusChanged: {
                        if (!activeFocus) return;
                        const left = mapToItem(locationsView.contentItem, 0, 0).x;
                        if (left < locationsView.contentX)
                            locationsView.contentX = left;
                        else if (left + width > locationsView.contentX + locationsView.width)
                            locationsView.contentX = Math.max(0, left + width - locationsView.width);
                    }
                    contentItem: Item {
                        NativeGlyph {
                            anchors.centerIn: parent
                            width: Math.min(16, parent.width)
                            height: width
                            roleName: shortcut.modelData.icon
                        }
                    }
                    background: Rectangle {
                        radius: 4
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, shortcut.down ? 0.12
                                           : shortcut.hovered || shortcut.activeFocus ? 0.07 : 0)
                    }
                    PlasmaComponents3.ToolTip { text: shortcut.text }
                    onClicked: {
                        if (placesRow.launch(modelData))
                            placesRow.shortcutInvoked();
                    }
                }
            }
        }
    }
}
