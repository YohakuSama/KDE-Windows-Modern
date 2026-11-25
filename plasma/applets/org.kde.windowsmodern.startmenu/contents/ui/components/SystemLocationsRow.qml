// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
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
    readonly property int buttonExtent: Math.max(24, Math.min(36,
        Math.floor(width / Math.max(1, visibleLocations.length))))
    implicitHeight: 40
    implicitWidth: visibleLocations.length * 36

    Flickable {
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
                    contentItem: Item {
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.min(18, parent.width)
                            height: width
                            source: shortcut.modelData.icon
                            isMask: true
                            color: Kirigami.Theme.textColor
                            roundToIconSize: false
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
                        if (placesRow.executable && modelData.command) {
                            placesRow.executable.exec(modelData.command);
                            placesRow.shortcutInvoked();
                        }
                    }
                }
            }
        }
    }
}
